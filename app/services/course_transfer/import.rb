require_relative "dependency_order"
require_relative "errors"
require_relative "file_transfer"
require_relative "import_finalizer"
require_relative "import_selection"
require_relative "serialization"

module CourseTransfer
  # Streams table files, resolves package-ID references, bulk-inserts rows,
  # validates them, and commits the complete import atomically.
  class ImportManager
    DEFAULT_BATCH_SIZE = 1_000

    PreparedRow = Struct.new(
      :package_id, :attributes, :database_match,
      keyword_init: true
    )
    private_constant :PreparedRow

    attr_reader :registry, :context, :batch_size

    # @param registry [CourseTransfer::ExportRegistry]
    # @param context [CourseTransfer::Context]
    # @param batch_size [Integer]
    def initialize(registry:, context:, batch_size: DEFAULT_BATCH_SIZE, selection: nil,
                   user_ids: nil, assessment_ids: nil)
      @registry = registry
      @context = context
      @selection = selection
      @user_ids = user_ids
      @assessment_ids = assessment_ids
      @batch_size = Integer(batch_size)
      raise ArgumentError, "batch size must be positive" unless @batch_size.positive?
    end

    # @return [Array<CourseTransfer::Exporter>]
    def import_order
      DependencyOrder.new(registry).call
    end

    # Imports the staged package in one transaction.
    #
    # @return [Course]
    def import
      if !@selection && (!@user_ids.nil? || !@assessment_ids.nil?)
        @selection = ImportSelection.new(
          registry:, context:, user_ids: @user_ids, assessment_ids: @assessment_ids
        )
      end
      parts = package_parts
      @course_identifier = destination_course_identifier
      @imported_ids = Hash.new { |hash, name| hash[name] = [] }
      cleanup = nil
      finalizer = nil

      ApplicationRecord.transaction(requires_new: true) do
        id_maps = Hash.new { |hash, name| hash[name] = {} }
        import_order.each do |exporter|
          next unless parts.include?(exporter.name)

          import_table(exporter, id_maps:)
        end

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

      Version.assert_importable!(
        version: manifest.fetch("version"),
        min_target: manifest.fetch("min_target_version")
      )
      parts = manifest.fetch("parts").map(&:to_sym).to_set
      parts.each { |name| registry.fetch(name) }
      raise InvalidPackage, "manifest must include courses" unless parts.include?(:courses)

      parts
    rescue UnknownExporter => e
      raise InvalidPackage, e.message
    rescue KeyError => e
      raise InvalidPackage, "manifest is missing #{e.key.inspect}"
    rescue Psych::SyntaxError => e
      raise InvalidPackage, "manifest.yml is invalid YAML: #{e.message}"
    end

    def table_documents(exporter)
      path = context.staging_path.join(exporter.filename)
      raise InvalidPackage, "#{exporter.filename} is missing" unless path.file?

      Enumerator.new do |documents|
        File.open(path, "rb") do |input|
          Serialization.each_document(input, filename: exporter.filename) do |document|
            documents << document
          end
        end
      rescue Psych::Exception => e
        raise InvalidPackage, "#{exporter.filename} is invalid YAML: #{e.message}"
      end
    end

    def import_table(exporter, id_maps:)
      id_maps[exporter.name]
      prepared_rows(exporter, id_maps:).each_slice(batch_size) do |rows|
        import_batch(exporter, rows, id_maps:)
      end
    rescue ActiveRecord::ActiveRecordError => e
      raise ImportError, "failed to import #{exporter.name}: #{e.message}"
    end

    def import_batch(exporter, rows, id_maps:)
      existing = find_database_ids(exporter, rows)
      if !exporter.reuse_existing? && existing.any?
        raise ImportCollision,
              "#{exporter.name} already contains matching record #{existing.first.first.inspect}"
      end

      missing = rows.reject do |row|
        existing.key?(database_match_signature(exporter, row.database_match))
      end
      unless missing.empty?
        # All imported models are validated before the transaction commits.
        # rubocop:disable Rails/SkipsModelValidations
        exporter.model_class.insert_all!(missing.map(&:attributes))
        # rubocop:enable Rails/SkipsModelValidations
      end
      resolved = existing.merge(find_database_ids(exporter, missing))
      inserted = missing.to_set { |row| database_match_signature(exporter, row.database_match) }

      rows.each do |row|
        signature = database_match_signature(exporter, row.database_match)
        id = resolved.fetch(signature) do
          raise ImportError,
                "could not find imported #{exporter.name} record #{row.package_id.inspect}"
        end
        id_maps[exporter.name][row.package_id] = id
        @imported_ids[exporter.name] << id if inserted.include?(signature)
      end
    end

    def prepared_rows(exporter, id_maps:)
      Enumerator.new do |rows|
        expected_id = 1
        table_documents(exporter).each do |document|
          validate_document!(exporter, document)
          package_id = document.fetch("_id")
          unless package_id == expected_id
            raise InvalidPackage,
                  "#{exporter.filename} expected _id #{expected_id}, got #{package_id.inspect}"
          end
          expected_id += 1

          next if @selection && !@selection.include?(exporter.name, document)

          attributes = exporter.fields.to_h do |field|
            value = document.fetch(field.to_s)
            value = resolve_reference(exporter.ref_fields.fetch(field), value, id_maps) if
              exporter.ref_fields.key?(field)
            [field, value]
          end
          attributes[:name] = @course_identifier if exporter.name == :courses
          if exporter.name == :courses && attributes[:cgdub_dependencies_updated_at].nil?
            attributes[:cgdub_dependencies_updated_at] = Time.current
          end
          database_match = exporter.match_fields.index_with { |field| attributes.fetch(field) }
          rows << PreparedRow.new(package_id:, attributes:, database_match:)
        end
      end
    end

    def validate_document!(exporter, document)
      unless document.is_a?(Hash)
        raise InvalidPackage, "#{exporter.filename} contains a non-object row"
      end

      fields = exporter.fields.map(&:to_s)
      expected = ["_id", *fields]
      unknown = document.keys - expected
      missing = expected - document.keys
      raise InvalidPackage, "#{exporter.filename} contains unknown fields: #{unknown.join(', ')}" if
        unknown.any?
      raise InvalidPackage, "#{exporter.filename} is missing fields: #{missing.join(', ')}" if
        missing.any?

      package_id = document.fetch("_id")
      return if package_id.is_a?(Integer) && package_id.positive?

      raise InvalidPackage, "#{exporter.filename} contains an invalid _id"
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

    def find_database_ids(exporter, rows)
      return {} if rows.empty?

      columns = [exporter.model_class.primary_key, *exporter.match_fields]
      lookup_field = exporter.match_fields.find { |field| exporter.ref_fields.key?(field) } ||
                     exporter.match_fields.first
      desired = rows.to_set { |row| database_match_signature(exporter, row.database_match) }
      found = {}

      lookup_values = rows.map { |row| row.database_match.fetch(lookup_field) }.uniq
      lookup_values.each_slice(batch_size) do |values|
        exporter.records_matching(lookup_field, values).pluck(*columns).each do |id, *key_values|
          database_match = exporter.match_fields.zip(key_values).to_h
          signature = database_match_signature(exporter, database_match)
          next unless desired.include?(signature)

          if found.key?(signature) && found.fetch(signature) != id
            if exporter.reuse_existing?
              found[signature] = [found.fetch(signature), id].min
              next
            end
            raise ImportCollision,
                  "#{exporter.name} has ambiguous matching fields #{database_match.inspect}"
          end
          found[signature] = id
        end
      end
      found
    end

    def validate_import
      errors = @imported_ids.flat_map do |name, ids|
        exporter = registry.fetch(name)
        exporter.model_class.where(id: ids.uniq).filter_map do |record|
          next if record.valid?

          "#{name} #{record.id}: #{record.errors.full_messages.join(', ')}"
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
      exporter = registry.fetch(:courses)
      documents = table_documents(exporter).to_a
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
      if cud.new_record?
        # Kept callback-free so finalization runs once for every imported row.
        # rubocop:disable Rails/SkipsModelValidations
        CourseUserDatum.insert_all!([cud.attributes.except("id")])
        # rubocop:enable Rails/SkipsModelValidations
        cud = CourseUserDatum.find_by!(course_id: course.id, user_id: user.id)
      else
        # rubocop:disable Rails/SkipsModelValidations
        CourseUserDatum.where(id: cud.id).update_all(instructor: true, dropped: false)
        # rubocop:enable Rails/SkipsModelValidations
      end
      @imported_ids[:course_user_data] << cud.id
    rescue ActiveRecord::ActiveRecordError => e
      raise ImportError, "failed to create import instructor: #{e.message}"
    end

    def database_match_signature(exporter, database_match)
      normalized = database_match.to_h do |field, value|
        value = exporter.normalize_match_value(field, value) unless exporter.ref_fields.key?(field)
        [field, value]
      end
      Serialization.canonical(normalized)
    end
  end
end
