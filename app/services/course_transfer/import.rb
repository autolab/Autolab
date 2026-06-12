require "json"
require "yaml"
require_relative "file_transfer"
require_relative "yaml_stream"

module CourseTransfer
  # Base error for package import failures.
  class ImportError < StandardError; end
  # Raised when immediate foreign-key dependencies contain a cycle.
  class CyclicImportDependencies < ImportError; end
  # Raised when package structure or row contents are invalid.
  class InvalidPackage < ImportError; end
  # Raised when a portable reference has no matching imported row.
  class MissingImportReference < ImportError; end
  # Raised when an imported key collides with existing database state.
  class ImportCollision < ImportError; end
  # Raised when imported records fail model validation before commit.
  class ImportValidationError < ImportError; end
  # Raised when the destination course identifier is missing, invalid, or used.
  class InvalidCourseIdentifier < ImportError; end

  # Determines a stable order in which table rows can be inserted with their
  # foreign keys already resolved.
  class ImportOrder
    # @param registry [CourseTransfer::ExportRegistry]
    def initialize(registry)
      @registry = registry
    end

    # @return [Array<CourseTransfer::Exporter>]
    def call
      ordered = []
      complete = {}
      visiting = []

      @registry.each do |exporter|
        visit(exporter, ordered:, complete:, visiting:)
      end

      ordered.freeze
    end

  private

    def visit(exporter, ordered:, complete:, visiting:)
      return if complete.key?(exporter.name)

      if visiting.include?(exporter.name)
        cycle = visiting.drop_while { |name| name != exporter.name } + [exporter.name]
        raise CyclicImportDependencies, "cyclic import dependency: #{cycle.join(' -> ')}"
      end

      visiting << exporter.name
      exporter.import_dependencies.each do |dependency_name|
        dependency = @registry.fetch(dependency_name)
        visit(dependency, ordered:, complete:, visiting:)
      end
      visiting.pop

      complete[exporter.name] = true
      ordered << exporter
    end
  end

  # Reads table files, resolves natural-key references, bulk-inserts rows in
  # dependency order, validates imported records, and commits atomically.
  class ImportManager
    DEFAULT_BATCH_SIZE = 1_000

    attr_reader :registry, :context, :batch_size

    # @param registry [CourseTransfer::ExportRegistry]
    # @param context [CourseTransfer::Context]
    # @param batch_size [Integer]
    def initialize(registry:, context:, batch_size: DEFAULT_BATCH_SIZE)
      @registry = registry
      @context = context
      @batch_size = batch_size
      @imported_ids = Hash.new { |hash, name| hash[name] = [] }
      @deferred_references = []
    end

    # @return [Array<CourseTransfer::Exporter>]
    def import_order
      ImportOrder.new(registry).call
    end

    # Imports the package under +context.staging_path+ in one transaction.
    # Existing users and identical score adjustments are reused; all other
    # natural-key collisions abort the transaction.
    #
    # @return [Course] imported course
    def import
      package = read_package
      @course_identifier = destination_course_identifier(package)
      cleanup = nil

      ApplicationRecord.transaction(requires_new: true) do
        key_maps = Hash.new { |hash, name| hash[name] = {} }

        import_order.each do |exporter|
          import_table(exporter, package.fetch(exporter.name, []), key_maps:)
        end

        resolve_deferred_references(key_maps:)
        imported = imported_course(key_maps)
        ensure_import_instructor(imported) if context.instructor_email.present?
        cleanup = FileTransfer.import(
          registry,
          context:,
          imported_ids: @imported_ids,
          key_maps:
        )
        validate_import
        imported
      end
    rescue StandardError
      cleanup&.cleanup!
      raise
    end

  private

    # Internal normalized representation of one package row.
    # @api private
    PreparedRow = Struct.new(
      :document, :package_key, :attributes, :database_key,
      keyword_init: true
    )

    def read_package
      manifest = Version.read_manifest(context.staging_path)
      raise InvalidPackage, "manifest.yml is missing" unless manifest

      Version.assert_importable!(
        version: manifest.fetch("version"),
        min_target: manifest.fetch("min_target_version")
      )

      Array(manifest.fetch("parts")).to_h do |part|
        name = part.to_sym
        exporter = registry.fetch(name)
        [name, read_table_file(exporter)]
      end
    rescue UnknownExporter => e
      raise InvalidPackage, e.message
    rescue KeyError => e
      raise InvalidPackage, "manifest is missing #{e.key.inspect}"
    rescue Psych::SyntaxError => e
      raise InvalidPackage, "manifest.yml is invalid YAML: #{e.message}"
    end

    def read_table_file(exporter)
      path = context.staging_path.join(exporter.filename)
      raise InvalidPackage, "#{exporter.filename} is missing" unless path.file?

      documents = YamlStream.load(path.read, filename: exporter.filename)
      unless documents.all?(Hash)
        raise InvalidPackage,
              "each document in #{exporter.filename} must contain one record mapping"
      end

      documents
    rescue Psych::Exception => e
      raise InvalidPackage, "#{exporter.filename} is invalid YAML: #{e.message}"
    end

    def import_table(exporter, documents, key_maps:)
      key_maps[exporter.name]
      prepared = prepare_rows(exporter, documents, key_maps:)
      return if prepared.empty?

      existing = find_database_ids(exporter, prepared)
      collisions = existing.keys unless exporter.reuse_existing?
      if collisions&.any?
        raise ImportCollision,
              "#{exporter.name} already contains natural key #{collisions.first.inspect}"
      end

      missing = prepared.reject do |row|
        existing.key?(database_key_signature(exporter, row.database_key))
      end
      missing.each_slice(batch_size) do |batch|
        # Bulk insertion is intentional; all imported records are validated as
        # persisted models before the surrounding transaction commits.
        # rubocop:disable Rails/SkipsModelValidations
        exporter.model_class.insert_all!(batch.map(&:attributes))
        # rubocop:enable Rails/SkipsModelValidations
      end

      resolved = find_database_ids(exporter, prepared)
      inserted_rows = missing.index_with { true }
      prepared.each do |row|
        database_signature = database_key_signature(exporter, row.database_key)
        id = resolved.fetch(database_signature) do
          raise ImportError,
                "could not find imported #{exporter.name} record #{row.package_key.inspect}"
        end
        key_maps[exporter.name][canonical_key(row.package_key)] = id
        @imported_ids[exporter.name] << id if inserted_rows.key?(row)
        collect_deferred_references(exporter, row, id)
      end
    rescue ActiveRecord::ActiveRecordError => e
      raise ImportError, "failed to import #{exporter.name}: #{e.message}"
    end

    def prepare_rows(exporter, documents, key_maps:)
      seen = {}

      documents.filter_map do |document|
        validate_document!(exporter, document)
        package_key = document.fetch("_key")
        signature = canonical_key(package_key)

        if seen.key?(signature)
          if seen.fetch(signature) != document
            raise InvalidPackage,
                  "#{exporter.filename} has conflicting rows for #{package_key.inspect}"
          end
          next
        end
        seen[signature] = document

        attributes = exporter.fields.each_with_object({}) do |field, result|
          next if exporter.deferred_ref_fields.include?(field)

          value = document.fetch(field.to_s)
          result[field] = if exporter.ref_fields.key?(field)
                            resolve_reference(
                              exporter.ref_fields.fetch(field), value, key_maps
                            )
                          else
                            value
                          end
        end
        attributes[:name] = @course_identifier if exporter.name == :courses
        database_key = exporter.key_fields.index_with { |field| attributes.fetch(field) }

        PreparedRow.new(document:, package_key:, attributes:, database_key:)
      end
    end

    def validate_document!(exporter, document)
      unless document.is_a?(Hash)
        raise InvalidPackage, "#{exporter.filename} contains a non-object row"
      end

      allowed = ["_key", *exporter.fields.map(&:to_s)]
      unknown = document.keys - allowed
      unless unknown.empty?
        raise InvalidPackage, "#{exporter.filename} contains unknown fields: #{unknown.join(', ')}"
      end

      missing = allowed - document.keys
      unless missing.empty?
        raise InvalidPackage, "#{exporter.filename} is missing fields: #{missing.join(', ')}"
      end

      expected_key = exporter.key_fields.to_h do |field|
        value = document.fetch(field.to_s)
        value = if exporter.ref_fields.key?(field) && value.is_a?(Hash)
                  value.fetch("key")
                else
                  exporter.normalize_key_value(field, value)
                end
        [field.to_s, value]
      end
      return if canonical_key(expected_key) == canonical_key(document.fetch("_key"))

      raise InvalidPackage, "#{exporter.filename} contains a row with an invalid _key"
    end

    def resolve_reference(expected_table, value, key_maps)
      return nil if value.nil?
      return value if value.is_a?(Numeric) && value <= 0

      unless value.is_a?(Hash) && value["table"].to_s == expected_table.to_s && value.key?("key")
        raise InvalidPackage, "invalid reference to #{expected_table}"
      end

      key_maps.fetch(expected_table).fetch(canonical_key(value.fetch("key"))) do
        raise MissingImportReference,
              "reference to missing #{expected_table} #{value.fetch('key').inspect}"
      end
    end

    def find_database_ids(exporter, prepared)
      return {} if prepared.empty?

      columns = [exporter.model_class.primary_key, *exporter.key_fields]
      lookup_field = exporter.key_fields.find do |field|
        exporter.ref_fields.key?(field)
      end || exporter.key_fields.first
      lookup_values = prepared.map { |row| row.database_key.fetch(lookup_field) }.uniq
      desired_signatures = prepared.to_h do |row|
        [database_key_signature(exporter, row.database_key), true]
      end
      found = {}

      lookup_values.each_slice(batch_size) do |values|
        exporter.model_class.where(lookup_field => values).pluck(*columns).each do |row|
          id, *key_values = row
          database_key = exporter.key_fields.zip(key_values).to_h
          signature = database_key_signature(exporter, database_key)
          next unless desired_signatures.key?(signature)

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

    def collect_deferred_references(exporter, row, id)
      exporter.deferred_ref_fields.each do |field|
        @deferred_references << {
          exporter:,
          id:,
          field:,
          value: row.document.fetch(field.to_s)
        }
      end
    end

    def resolve_deferred_references(key_maps:)
      @deferred_references.each do |reference|
        exporter = reference.fetch(:exporter)
        field = reference.fetch(:field)
        target = exporter.ref_fields.fetch(field)
        value = resolve_reference(target, reference.fetch(:value), key_maps)
        # Deferred references are followed by full validation before commit.
        # rubocop:disable Rails/SkipsModelValidations
        exporter.model_class.where(id: reference.fetch(:id)).update_all(field => value)
        # rubocop:enable Rails/SkipsModelValidations
      end
    end

    def validate_import
      errors = []
      registry.each do |exporter|
        ids = @imported_ids.fetch(exporter.name, []).uniq
        exporter.model_class.where(id: ids).find_each do |record|
          next if record.valid?

          errors << "#{exporter.name} #{record.id}: #{record.errors.full_messages.join(', ')}"
        end
      end
      return if errors.empty?

      raise ImportValidationError, errors.first(20).join("; ")
    end

    def imported_course(key_maps)
      ids = key_maps.fetch(:courses).values.uniq
      raise InvalidPackage, "a package must contain exactly one course" unless ids.one?

      Course.find(ids.first)
    end

    def destination_course_identifier(package)
      course_documents = package.fetch(:courses, [])
      unless course_documents.one? && course_documents.first["name"].present?
        raise InvalidPackage, "a package must contain exactly one named course"
      end

      identifier = context.course_identifier.presence || course_documents.first.fetch("name")
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
        user = User.new(
          email:,
          first_name: "Instructor",
          last_name: course.name
        )
        User.assign_random_password(user)
        user.save!
        @imported_ids[:users] << user.id
      end

      cud = CourseUserDatum.find_by(course_id: course.id, user_id: user.id)
      if cud
        # The imported instructor override is intentionally applied in bulk,
        # alongside the rest of the import's bulk writes.
        # rubocop:disable Rails/SkipsModelValidations
        CourseUserDatum.where(id: cud.id).update_all(instructor: true, dropped: false)
        # rubocop:enable Rails/SkipsModelValidations
      else
        # This is intentionally inserted without lifecycle callbacks, matching
        # the bulk-import path used for package CUD rows.
        # rubocop:disable Rails/SkipsModelValidations
        CourseUserDatum.insert_all!([{
                                      course_id: course.id,
                                      user_id: user.id,
                                      instructor: true,
                                      dropped: false,
                                      course_assistant: false,
                                      section: "",
                                      grade_policy: "",
                                      course_number: ""
                                    }])
        # rubocop:enable Rails/SkipsModelValidations
        cud = CourseUserDatum.find_by!(course_id: course.id, user_id: user.id)
      end

      @imported_ids[:course_user_data] << cud.id
    rescue ActiveRecord::ActiveRecordError => e
      raise ImportError, "failed to create import instructor: #{e.message}"
    end

    def canonical_key(value)
      JSON.generate(normalize(value))
    end

    def database_key_signature(exporter, database_key)
      normalized = database_key.to_h do |field, value|
        normalized_value = if exporter.ref_fields.key?(field)
                             value
                           else
                             exporter.normalize_key_value(field, value)
                           end
        [field, normalized_value]
      end
      canonical_key(normalized)
    end

    def normalize(value)
      case value
      when Time, DateTime
        value.iso8601(6)
      when Date
        value.iso8601
      when Hash
        value.sort.to_h.transform_values { |nested| normalize(nested) }
      when Array
        value.map { |nested| normalize(nested) }
      else
        value
      end
    end
  end
end
