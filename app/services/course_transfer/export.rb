require "bigdecimal"
require "fileutils"
require "json"
require "yaml"
require_relative "file_transfer"

# Services for portable, normalized course packages.
module CourseTransfer
  # Base error for export planning and writing failures.
  class ExportError < StandardError; end
  # Raised when a package table has no registered exporter.
  class UnknownExporter < ExportError; end
  # Raised when two exporters claim the same package table.
  class DuplicateExporter < ExportError; end
  # Raised when a row references a record outside the export plan.
  class MissingExportReference < ExportError; end
  # Raised when different rows produce one portable key.
  class DuplicateNaturalKey < ExportError; end

  # Describes one database table and its corresponding package file.
  # Concrete exporters contain declarations and lazy dependency scopes only;
  # orchestration and serialization are shared by all tables.
  class Exporter
    attr_reader :name, :model_class, :filename

    # @param name [Symbol] stable package name for this table
    # @param model_class [Class<ApplicationRecord>] exported Active Record model
    # @param filename [String, nil] package-relative YAML filename
    def initialize(name:, model_class:, filename: nil)
      @name = name.to_sym
      @model_class = model_class
      @filename = filename || "#{name}.yml"
    end

    # Returns records in other table files required by +relation+.
    # Implementations must return lazy, structurally compatible relations.
    #
    # @param _relation [ActiveRecord::Relation]
    # @return [Hash{Symbol => ActiveRecord::Relation}]
    def dependencies(_relation)
      {}
    end

    # Adds any joins or SQL transformations required before plucking rows.
    #
    # @param relation [ActiveRecord::Relation]
    # @return [ActiveRecord::Relation]
    def query(relation)
      relation
    end

    # Database columns exported for each record, excluding the primary key.
    # Foreign-key columns must also occur in {#ref_fields}.
    #
    # @return [Array<Symbol>]
    def fields
      []
    end

    # Qualified fields plucked by the shared writer. The primary key is used
    # internally to construct reference maps and is never written as a record
    # attribute.
    #
    # @return [Array<String>]
    def pluck_fields
      [model_class.primary_key, *fields].map do |field|
        "#{model_class.table_name}.#{field}"
      end
    end

    # Maps local foreign-key columns to referenced table exporters.
    #
    # @return [Hash{Symbol => Symbol}]
    def ref_fields
      {}
    end

    # Columns forming this table's portable natural key. Foreign-key
    # components are replaced with the referenced record's natural key.
    #
    # @return [Array<Symbol>]
    def key_fields
      []
    end

    # Normalizes a direct natural-key component. Exporters with
    # case-insensitive uniqueness override this for stable matching.
    #
    # @param _field [Symbol]
    # @param value [Object]
    # @return [Object]
    def normalize_key_value(_field, value)
      value
    end

    # References resolved after normal insertion for genuinely cyclic tables.
    #
    # @return [Array<Symbol>]
    def deferred_ref_fields
      []
    end

    # Whether an existing database record with the same natural key may be
    # reused instead of treating it as an import collision.
    #
    # @return [Boolean]
    def reuse_existing?
      false
    end

    # Table files that must be imported before this one.
    #
    # @return [Array<Symbol>]
    def import_dependencies
      immediate_refs = ref_fields.reject do |field, _exporter_name|
        deferred_ref_fields.include?(field)
      end

      immediate_refs.values.uniq
    end

    # Converts plucked values to a column-keyed row.
    #
    # @param values [Array<Object>]
    # @return [Hash{String => Object}]
    def row_from(values)
      columns = [model_class.primary_key.to_sym, *fields]
      columns.map(&:to_s).zip(values).to_h
    end

    # Returns file mappings owned by records in +relation+.
    #
    # @param _relation [ActiveRecord::Relation]
    # @return [Array<CourseTransfer::FileMapping>]
    def file_mappings(_relation)
      []
    end
  end

  # Holds the exporter for every table file in a package.
  class ExportRegistry
    include Enumerable

    def initialize
      @exporters = {}
    end

    # @param exporter [CourseTransfer::Exporter]
    # @return [CourseTransfer::ExportRegistry] self
    def register(exporter)
      if @exporters.key?(exporter.name)
        raise DuplicateExporter, "exporter #{exporter.name.inspect} is already registered"
      end

      @exporters[exporter.name] = exporter
      self
    end

    # @param name [String, Symbol]
    # @return [CourseTransfer::Exporter]
    def fetch(name)
      @exporters.fetch(name.to_sym) do
        raise UnknownExporter, "no exporter registered for #{name.inspect}"
      end
    end

    # @param name [String, Symbol]
    # @return [Boolean]
    def key?(name)
      @exporters.key?(name.to_sym)
    end

    # @yieldparam exporter [CourseTransfer::Exporter]
    # @return [Enumerator, Hash]
    def each(&block)
      @exporters.each_value(&block)
    end

    # @return [Array<Symbol>]
    def names
      @exporters.keys
    end
  end

  # User-facing scope for a course export. The course is always included.
  # Submissions are the intersection of the chosen users and assessments.
  class ExportSelection
    attr_reader :course, :users, :assessments

    # @param course [Course]
    # @param users [ActiveRecord::Relation<User>, nil]
    # @param assessments [ActiveRecord::Relation<Assessment>, nil]
    def initialize(course:, users: nil, assessments: nil)
      @course = course
      @users = users || User.none
      @assessments = assessments || Assessment.none
    end

    # Returns the intentionally selected rows before support dependencies are
    # recursively added. All selections are constrained to +course+.
    #
    # @return [Hash{Symbol => ActiveRecord::Relation}]
    def seed_relations
      selected_assessments = Assessment.where(
        course_id: course.id,
        id: assessments.select(:id)
      )
      selected_memberships = CourseUserDatum.where(
        course_id: course.id,
        user_id: users.select(:id)
      )
      selected_users = User.where(id: selected_memberships.select(:user_id))
      selected_submissions = Submission.where(
        assessment_id: selected_assessments.select(:id),
        course_user_datum_id: selected_memberships.select(:id)
      )

      {
        courses: Course.where(id: course.id),
        users: selected_users,
        course_user_data: selected_memberships,
        assessments: selected_assessments,
        submissions: selected_submissions,
        assessment_user_data: AssessmentUserDatum.where(
          assessment_id: selected_assessments.select(:id),
          course_user_datum_id: selected_memberships.select(:id)
        ),
        extensions: Extension.where(
          assessment_id: selected_assessments.select(:id),
          course_user_datum_id: selected_memberships.select(:id)
        )
      }
    end
  end

  # Immutable collection of lazy relations selected for table-file export.
  class ExportPlan
    include Enumerable

    # @param relations [Hash{Symbol => ActiveRecord::Relation}]
    def initialize(relations)
      @relations = relations.transform_keys(&:to_sym).freeze
    end

    # @param name [String, Symbol]
    # @return [ActiveRecord::Relation]
    def relation_for(name)
      @relations.fetch(name.to_sym)
    end

    # @yieldparam name [Symbol]
    # @yieldparam relation [ActiveRecord::Relation]
    # @return [Enumerator, Hash]
    def each(&block)
      @relations.each(&block)
    end

    # @return [Array<Symbol>]
    def names
      @relations.keys
    end
  end

  # Builds dependency closure and writes one batched YAML file per table.
  class ExportManager
    DEFAULT_BATCH_SIZE = 1_000

    attr_reader :registry, :context, :batch_size

    # @param registry [CourseTransfer::ExportRegistry]
    # @param context [CourseTransfer::Context]
    # @param batch_size [Integer]
    def initialize(registry:, context:, batch_size: DEFAULT_BATCH_SIZE)
      @registry = registry
      @context = context
      @batch_size = batch_size
    end

    # Recursively expands a configured selection into all supporting records.
    # Dependency scopes remain lazy until files are written.
    #
    # @param selection [CourseTransfer::ExportSelection]
    # @return [CourseTransfer::ExportPlan]
    def build_plan(selection)
      fragments = Hash.new { |hash, name| hash[name] = [] }
      queue = selection.seed_relations.to_a

      until queue.empty?
        name, relation = queue.shift
        name = name.to_sym
        registry.fetch(name)
        fragments[name] << relation

        registry.fetch(name).dependencies(relation).each do |dependency_name, dependency_relation|
          queue << [dependency_name.to_sym, dependency_relation]
        end
      end

      relations = fragments.transform_values do |scopes|
        scopes.reduce { |combined, scope| combined.or(scope) }
      end
      ExportPlan.new(relations)
    end

    # Writes all table files and the package manifest.
    #
    # @param plan [CourseTransfer::ExportPlan]
    # @return [CourseTransfer::ExportPlan]
    def export(plan)
      FileUtils.mkdir_p(context.staging_path)
      key_maps = Hash.new { |hash, name| hash[name] = {} }

      registry.each do |exporter|
        next unless plan.names.include?(exporter.name)

        key_maps[exporter.name]
        write_table(exporter, plan.relation_for(exporter.name), key_maps)
      end

      Version.write_manifest!(context, parts: plan.names)
      FileTransfer.export(plan, registry, context:, key_maps:)
      plan
    end

  private

    def write_table(exporter, relation, key_maps)
      path = context.staging_path.join(exporter.filename)
      seen_documents = {}

      File.open(path, "w") do |file|
        each_plucked_row(exporter, relation) do |row|
          document, natural_key = serialize_row(exporter, row, key_maps)
          signature = canonical_key(natural_key)
          key_maps[exporter.name][row.fetch(exporter.model_class.primary_key)] = natural_key

          if seen_documents.key?(signature)
            unless seen_documents.fetch(signature) == document
              raise DuplicateNaturalKey,
                    "#{exporter.name} contains conflicting records for #{natural_key.inspect}"
            end
            next
          end

          seen_documents[signature] = document
          file.write(YAML.dump(normalize(document)))
        end
      end
    end

    def each_plucked_row(exporter, relation)
      primary_key = exporter.model_class.primary_key
      scope = exporter.query(relation).reorder(primary_key => :asc)
      last_id = nil

      loop do
        batch = scope
        if last_id
          batch = batch.where(
            "#{exporter.model_class.table_name}.#{primary_key} > ?", last_id
          )
        end
        values = batch.limit(batch_size).pluck(*exporter.pluck_fields)
        break if values.empty?

        values.each { |row_values| yield exporter.row_from(row_values) }
        last_id = values.last.first
      end
    end

    def serialize_row(exporter, row, key_maps)
      natural_key = natural_key_for(exporter, row, key_maps)
      document = { "_key" => natural_key }

      exporter.fields.each do |field|
        field_name = field.to_s
        target_name = exporter.ref_fields[field]
        document[field_name] = if target_name
                                 reference_document(target_name, row[field_name], key_maps)
                               else
                                 row[field_name]
                               end
      end

      [document, natural_key]
    end

    def natural_key_for(exporter, row, key_maps)
      if exporter.key_fields.empty?
        raise ExportError, "#{exporter.name} does not declare a natural key"
      end

      exporter.key_fields.to_h do |field|
        value = row.fetch(field.to_s)
        target_name = exporter.ref_fields[field]
        key_value = if target_name
                      reference_key(target_name, value, key_maps)
                    else
                      exporter.normalize_key_value(field, value)
                    end
        [field.to_s, key_value]
      end
    end

    def reference_document(target_name, source_id, key_maps)
      return nil if source_id.nil?
      return source_id if source_id.respond_to?(:negative?) && source_id <= 0

      {
        "table" => target_name.to_s,
        "key" => reference_key(target_name, source_id, key_maps)
      }
    end

    def reference_key(target_name, source_id, key_maps)
      return source_id if source_id.respond_to?(:negative?) && source_id <= 0

      key_maps.fetch(target_name).fetch(source_id.to_s) do
        key_maps.fetch(target_name).fetch(source_id) do
          raise MissingExportReference,
                "#{target_name} record #{source_id.inspect} was referenced but not exported"
        end
      end
    end

    def normalize(value)
      case value
      when BigDecimal
        value.to_s
      when ActiveSupport::TimeWithZone
        value.iso8601(6)
      when Time, DateTime
        value.iso8601(6)
      when Date
        value.iso8601
      when Hash
        value.transform_values { |nested| normalize(nested) }
      when Array
        value.map { |nested| normalize(nested) }
      else
        value
      end
    end

    def canonical_key(value)
      JSON.generate(normalize(value))
    end
  end
end
