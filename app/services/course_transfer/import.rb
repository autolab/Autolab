require_relative "dependency_order"
require_relative "errors"
require_relative "file_transfer"
require_relative "import_finalizer"
require_relative "serialization"

module CourseTransfer
  # Streams table files, resolves natural-key references, bulk-inserts rows,
  # validates them, and commits the complete import atomically.
  class ImportManager
    DEFAULT_BATCH_SIZE = 1_000

    PreparedRow = Struct.new(
      :document, :package_key, :attributes, :database_key,
      keyword_init: true
    )
    private_constant :PreparedRow

    attr_reader :registry, :context, :batch_size

    # @param registry [CourseTransfer::ExportRegistry]
    # @param context [CourseTransfer::Context]
    # @param batch_size [Integer]
    def initialize(registry:, context:, batch_size: DEFAULT_BATCH_SIZE)
      @registry = registry
      @context = context
      @batch_size = batch_size
    end

    # @return [Array<CourseTransfer::Exporter>]
    def import_order
      DependencyOrder.new(registry).call
    end

    # Imports the staged package in one transaction.
    #
    # @return [Course]
    def import
      parts = package_parts
      @course_identifier = destination_course_identifier
      @imported_ids = Hash.new { |hash, name| hash[name] = [] }
      cleanup = nil
      finalizer = nil

      ApplicationRecord.transaction(requires_new: true) do
        key_maps = Hash.new { |hash, name| hash[name] = {} }
        import_order.each do |exporter|
          next unless parts.include?(exporter.name)

          import_table(exporter, key_maps:)
        end

        course = imported_course(key_maps)
        ensure_import_instructor(course) if context.instructor_email.present?
        validate_import
        cleanup = FileTransfer.import(
          registry, context:, imported_ids: @imported_ids, key_maps:
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
      parts = Array(manifest.fetch("parts")).map(&:to_sym)
      parts.each { |name| registry.fetch(name) }
      raise InvalidPackage, "manifest contains duplicate table files" unless parts.uniq == parts
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

    def import_table(exporter, key_maps:)
      key_maps[exporter.name]
      prepared_rows(exporter, key_maps:).each_slice(batch_size) do |rows|
        import_batch(exporter, rows, key_maps:)
      end
    rescue ActiveRecord::ActiveRecordError => e
      raise ImportError, "failed to import #{exporter.name}: #{e.message}"
    end

    def import_batch(exporter, rows, key_maps:)
      existing = find_database_ids(exporter, rows)
      if !exporter.reuse_existing? && existing.any?
        raise ImportCollision,
              "#{exporter.name} already contains natural key #{existing.first.first.inspect}"
      end

      missing = rows.reject do |row|
        existing.key?(database_key_signature(exporter, row.database_key))
      end
      unless missing.empty?
        # All imported models are validated before the transaction commits.
        # rubocop:disable Rails/SkipsModelValidations
        exporter.model_class.insert_all!(missing.map(&:attributes))
        # rubocop:enable Rails/SkipsModelValidations
      end
      resolved = existing.merge(find_database_ids(exporter, missing))
      inserted = missing.to_h { |row| [database_key_signature(exporter, row.database_key), true] }

      rows.each do |row|
        signature = database_key_signature(exporter, row.database_key)
        id = resolved.fetch(signature) do
          raise ImportError,
                "could not find imported #{exporter.name} record #{row.package_key.inspect}"
        end
        key_maps[exporter.name][Serialization.canonical(row.package_key)] = id
        @imported_ids[exporter.name] << id if inserted[signature]
      end
    end

    def prepared_rows(exporter, key_maps:)
      Enumerator.new do |rows|
        seen = {}
        table_documents(exporter).each do |document|
          validate_document!(exporter, document)
          package_key = document.fetch("_key")
          signature = Serialization.canonical(package_key)
          canonical_document = Serialization.canonical(document)
          if seen.key?(signature)
            unless seen.fetch(signature) == canonical_document
              raise InvalidPackage,
                    "#{exporter.filename} has conflicting rows for #{package_key.inspect}"
            end
            next
          end
          seen[signature] = canonical_document

          attributes = exporter.fields.to_h do |field|
            value = document.fetch(field.to_s)
            value = resolve_reference(exporter.ref_fields.fetch(field), value, key_maps) if
              exporter.ref_fields.key?(field)
            [field, value]
          end
          attributes[:name] = @course_identifier if exporter.name == :courses
          database_key = exporter.key_fields.index_with { |field| attributes.fetch(field) }
          rows << PreparedRow.new(document:, package_key:, attributes:, database_key:)
        end
      end
    end

    def validate_document!(exporter, document)
      unless document.is_a?(Hash)
        raise InvalidPackage, "#{exporter.filename} contains a non-object row"
      end

      fields = exporter.fields.map(&:to_s)
      expected = ["_key", *fields]
      unknown = document.keys - expected
      missing = expected - document.keys
      raise InvalidPackage, "#{exporter.filename} contains unknown fields: #{unknown.join(', ')}" if
        unknown.any?
      raise InvalidPackage, "#{exporter.filename} is missing fields: #{missing.join(', ')}" if
        missing.any?

      natural_key = exporter.key_fields.to_h do |field|
        value = document.fetch(field.to_s)
        value = value.fetch("key") if exporter.ref_fields.key?(field) && value.is_a?(Hash)
        [field.to_s, exporter.normalize_key_value(field, value)]
      end
      return if Serialization.canonical(natural_key) ==
                Serialization.canonical(document.fetch("_key"))

      raise InvalidPackage, "#{exporter.filename} contains a row with an invalid _key"
    end

    def resolve_reference(expected_table, value, key_maps)
      return nil if value.nil?
      return value if value.is_a?(Numeric) && value <= 0

      valid = value.is_a?(Hash) && value["table"].to_s == expected_table.to_s &&
              value.key?("key")
      raise InvalidPackage, "invalid reference to #{expected_table}" unless valid

      key_maps.fetch(expected_table).fetch(Serialization.canonical(value.fetch("key"))) do
        raise MissingImportReference,
              "reference to missing #{expected_table} #{value.fetch('key').inspect}"
      end
    end

    def find_database_ids(exporter, rows)
      return {} if rows.empty?

      columns = [exporter.model_class.primary_key, *exporter.key_fields]
      lookup_field = exporter.key_fields.find { |field| exporter.ref_fields.key?(field) } ||
                     exporter.key_fields.first
      desired = rows.to_h do |row|
        [database_key_signature(exporter, row.database_key), true]
      end
      found = {}

      lookup_values = rows.map { |row| row.database_key.fetch(lookup_field) }.uniq
      lookup_values.each_slice(batch_size) do |values|
        exporter.records_matching(lookup_field, values).pluck(*columns).each do |id, *key_values|
          database_key = exporter.key_fields.zip(key_values).to_h
          signature = database_key_signature(exporter, database_key)
          next unless desired[signature]

          if found.key?(signature) && found.fetch(signature) != id
            if exporter.reuse_existing?
              found[signature] = [found.fetch(signature), id].min
              next
            end
            raise ImportCollision,
                  "#{exporter.name} has an ambiguous natural key #{database_key.inspect}"
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

    def imported_course(key_maps)
      ids = key_maps.fetch(:courses).values.uniq
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

    def database_key_signature(exporter, database_key)
      normalized = database_key.to_h do |field, value|
        value = exporter.normalize_key_value(field, value) unless exporter.ref_fields.key?(field)
        [field, value]
      end
      Serialization.canonical(normalized)
    end
  end
end
