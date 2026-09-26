require_relative "errors"
require_relative "file_transfer"
require_relative "import_finalizer"
require_relative "import_selection"
require_relative "schema"
require_relative "serialization"
require_relative "version"

module CourseTransfer
  class ImportManager
    attr_reader :context

    def initialize(context:, selection: nil, user_ids: nil, assessment_ids: nil)
      @context = context
      @selection = selection
      @user_ids = user_ids
      @assessment_ids = assessment_ids
    end

    def import
      @selection ||= ImportSelection.new(
        context:, user_ids: @user_ids, assessment_ids: @assessment_ids
      ) if !@user_ids.nil? || !@assessment_ids.nil?
      parts = package_parts
      @course_identifier = destination_course_identifier
      @imported_ids = Hash.new { |hash, name| hash[name] = [] }
      cleanup = nil
      finalizer = nil

      ApplicationRecord.transaction(requires_new: true) do
        id_maps = Hash.new { |hash, name| hash[name] = {} }
        Schema.each { |table| import_table(table, id_maps) if parts.include?(table.name) }

        course = imported_course(id_maps)
        ensure_import_instructor(course) if context.instructor_email.present?
        cleanup = FileTransfer.import(
          context:, imported_ids: @imported_ids, id_maps:, selection: @selection
        )
        finalizer = ImportFinalizer.new(course, imported_ids: @imported_ids)
        finalizer.finalize!
        validate_import
        course
      end
    rescue StandardError
      finalizer&.cleanup!
      cleanup&.cleanup!
      raise
    end

  private

    def package_parts
      manifest = Version.read_manifest(context.staging_path)
      raise InvalidPackage, "manifest.yml is missing" unless manifest

      Version.assert_importable!(manifest.fetch("version"))
      parts = manifest.fetch("parts").map(&:to_sym).to_set
      parts.each { |name| Schema.fetch(name) }
      raise InvalidPackage, "manifest must include courses" unless parts.include?(:courses)

      parts
    rescue KeyError => e
      raise InvalidPackage, "invalid manifest entry: #{e.message}"
    rescue Psych::SyntaxError => e
      raise InvalidPackage, "manifest.yml is invalid YAML: #{e.message}"
    end

    def table_documents(table)
      path = context.staging_path.join(table.filename)
      raise InvalidPackage, "#{table.filename} is missing" unless path.file?

      Enumerator.new do |documents|
        File.open(path, "rb") do |input|
          Serialization.each_document(input, filename: table.filename) do |document|
            documents << document
          end
        end
      rescue Psych::Exception => e
        raise InvalidPackage, "#{table.filename} is invalid YAML: #{e.message}"
      end
    end

    def import_table(table, id_maps)
      expected_id = 0
      table_documents(table).each do |document|
        validate_document!(table, document)
        package_id = document.fetch("_id")
        expected_id += 1
        if package_id != expected_id
          raise InvalidPackage,
                "#{table.filename} expected _id #{expected_id}, got #{package_id.inspect}"
        end
        next if @selection && !@selection.include?(table.name, document)

        attributes = table.fields.to_h do |field|
          value = document.fetch(field.to_s)
          value = resolve_reference(table.ref_fields.fetch(field), value, id_maps) if
            table.ref_fields.key?(field)
          [field, value]
        end
        attributes[:name] = @course_identifier if table.name == :courses
        if table.name == :courses && attributes[:cgdub_dependencies_updated_at].nil?
          attributes[:cgdub_dependencies_updated_at] = Time.current
        end
        database_match = table.match_fields.index_with { |field| attributes.fetch(field) }
        database_id, inserted = insert_or_reuse(table, attributes, database_match)
        id_maps[table.name][package_id] = database_id
        @imported_ids[table.name] << database_id if inserted
      end
    rescue ActiveRecord::ActiveRecordError => e
      raise ImportError, "failed to import #{table.name}: #{e.message}"
    end

    def insert_or_reuse(table, attributes, database_match)
      existing = matching_ids(table, database_match)
      if existing.any?
        unless table.reuse_existing?
          raise ImportCollision, "#{table.name} already contains #{database_match.inspect}"
        end
        return [existing.min, false]
      end

      # Callbacks are intentionally skipped; ImportFinalizer rebuilds derived state once.
      # rubocop:disable Rails/SkipsModelValidations
      table.model_class.insert_all!([attributes])
      # rubocop:enable Rails/SkipsModelValidations
      inserted = matching_ids(table, database_match)
      raise ImportError, "could not find imported #{table.name} record" unless inserted.one?

      [inserted.first, true]
    end

    def matching_ids(table, database_match)
      lookup_field = table.match_fields.find { |field| table.ref_fields.key?(field) } ||
                     table.match_fields.first
      scope = table.records_matching(lookup_field, [database_match.fetch(lookup_field)])
      desired = database_match_signature(table, database_match)
      columns = [table.model_class.primary_key, *table.match_fields]
      scope.pluck(*columns).filter_map do |id, *values|
        candidate = table.match_fields.zip(values).to_h
        id if database_match_signature(table, candidate) == desired
      end
    end

    def validate_document!(table, document)
      unless document.is_a?(Hash)
        raise InvalidPackage, "#{table.filename} contains a non-object row"
      end

      expected = ["_id", *table.fields.map(&:to_s)]
      unknown = document.keys - expected
      missing = expected - document.keys
      raise InvalidPackage, "#{table.filename} contains unknown fields: #{unknown.join(', ')}" if
        unknown.any?
      raise InvalidPackage, "#{table.filename} is missing fields: #{missing.join(', ')}" if
        missing.any?

      package_id = document.fetch("_id")
      return if package_id.is_a?(Integer) && package_id.positive?

      raise InvalidPackage, "#{table.filename} contains an invalid _id"
    end

    def resolve_reference(expected_table, value, id_maps)
      return nil if value.nil?
      return value if value.is_a?(Numeric) && value <= 0

      valid = value.is_a?(Hash) && value["table"].to_s == expected_table.to_s &&
              value["id"].is_a?(Integer) && value["id"].positive?
      raise InvalidPackage, "invalid reference to #{expected_table}" unless valid

      id_maps.fetch(expected_table).fetch(value.fetch("id")) do
        raise MissingImportReference,
              "reference to missing #{expected_table} ID #{value.fetch('id').inspect}"
      end
    end

    def validate_import
      errors = @imported_ids.flat_map do |name, ids|
        table = Schema.fetch(name)
        table.model_class.where(id: ids.uniq).filter_map do |record|
          "#{name} #{record.id}: #{record.errors.full_messages.join(', ')}" unless record.valid?
        end
      end
      raise ImportValidationError, errors.first(20).join("; ") if errors.any?
    end

    def imported_course(id_maps)
      ids = id_maps.fetch(:courses).values.uniq
      raise InvalidPackage, "a package must contain exactly one course" unless ids.one?

      Course.find(ids.first)
    end

    def destination_course_identifier
      documents = table_documents(Schema.fetch(:courses)).to_a
      unless documents.one? && documents.first["name"].present?
        raise InvalidPackage, "a package must contain exactly one named course"
      end

      identifier = context.course_identifier.presence || documents.first.fetch("name")
      unless identifier.match?(/\A(\w|-)+\z/)
        raise InvalidCourseIdentifier,
              "course identifier may contain only letters, numbers, underscores, and hyphens"
      end
      if Course.where("LOWER(name) = ?", identifier.downcase).exists?
        raise InvalidCourseIdentifier, "course identifier #{identifier.inspect} already exists"
      end

      identifier
    end

    def ensure_import_instructor(course)
      email = context.instructor_email
      user = User.where("LOWER(email) = ?", email.downcase).first
      unless user
        user = User.new(email:, first_name: "Instructor", last_name: course.name)
        User.assign_random_password(user)
        user.save!
        @imported_ids[:users] << user.id
      end

      cud = CourseUserDatum.find_or_initialize_by(course_id: course.id, user_id: user.id)
      cud.assign_attributes(instructor: true, dropped: false)
      # rubocop:disable Rails/SkipsModelValidations
      if cud.new_record?
        CourseUserDatum.insert_all!([cud.attributes.except("id")])
        cud = CourseUserDatum.find_by!(course_id: course.id, user_id: user.id)
      else
        CourseUserDatum.where(id: cud.id).update_all(instructor: true, dropped: false)
      end
      # rubocop:enable Rails/SkipsModelValidations
      @imported_ids[:course_user_data] << cud.id
    rescue ActiveRecord::ActiveRecordError => e
      raise ImportError, "failed to create import instructor: #{e.message}"
    end

    def database_match_signature(table, database_match)
      normalized = database_match.to_h do |field, value|
        value = table.normalize_match_value(field, value) unless table.ref_fields.key?(field)
        [field, value]
      end
      Serialization.canonical(normalized)
    end
  end
end
