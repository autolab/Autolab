require "fileutils"
require_relative "dependency_order"
require_relative "errors"
require_relative "file_transfer"
require_relative "serialization"

# Services for portable, normalized course packages.
module CourseTransfer
  # Describes one database table and its corresponding package file.
  # Concrete exporters contain declarations and lazy dependency scopes only;
  # orchestration and serialization are shared by all tables.
  class Exporter
    attr_reader :name, :model_class

    class << self
      attr_reader :table_name, :table_model, :declared_fields,
                  :declared_references, :declared_key, :normalized_key_fields

      def table(name, model)
        @table_name = name
        @table_model = model
      end

      def export_fields(*fields)
        @declared_fields = fields
      end

      def references(**references)
        @declared_references = references
      end

      def natural_key(*fields, case_insensitive: [])
        @declared_key = fields
        @normalized_key_fields = Array(case_insensitive)
      end

      def reuse_existing
        @reuse_existing = true
      end

      def reuse_existing?
        @reuse_existing || false
      end
    end

    # @param name [Symbol] stable package name for this table
    # @param model_class [Class<ApplicationRecord>] exported Active Record model
    def initialize(name: self.class.table_name, model_class: self.class.table_model)
      raise ArgumentError, "exporter table and model are required" unless name && model_class

      @name = name.to_sym
      @model_class = model_class
    end

    # @return [String] package-relative YAML filename
    def filename
      "#{name}.yml"
    end

    # Returns records in other table files required by +relation+.
    # Implementations must return lazy, structurally compatible relations.
    #
    # @param _relation [ActiveRecord::Relation]
    # @return [Hash{Symbol => ActiveRecord::Relation}]
    def dependencies(_relation)
      {}
    end

    # Database columns exported for each record, excluding the primary key.
    # Foreign-key columns must also occur in {#ref_fields}.
    #
    # @return [Array<Symbol>]
    def fields
      self.class.declared_fields || []
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
      self.class.declared_references || {}
    end

    # Columns forming this table's portable natural key. Foreign-key
    # components are replaced with the referenced record's natural key.
    #
    # @return [Array<Symbol>]
    def key_fields
      self.class.declared_key || []
    end

    # Normalizes a direct natural-key component. Exporters with
    # case-insensitive uniqueness override this for stable matching.
    #
    # @param field [Symbol]
    # @param value [Object]
    # @return [Object]
    def normalize_key_value(field, value)
      self.class.normalized_key_fields&.include?(field) ? value.to_s.downcase : value
    end

    # Whether an existing database record with the same natural key may be
    # reused instead of treating it as an import collision.
    #
    # @return [Boolean]
    def reuse_existing?
      self.class.reuse_existing?
    end

    # Table files that must be imported before this one.
    #
    # @return [Array<Symbol>]
    def import_dependencies
      ref_fields.values.uniq
    end

    # Narrows a natural-key lookup. Exporters may override this when the
    # database treats a key component case-insensitively.
    #
    # @param field [Symbol]
    # @param values [Array<Object>]
    # @return [ActiveRecord::Relation]
    def records_matching(field, values)
      model_class.where(field => values)
    end

    # Converts plucked values to a column-keyed row.
    #
    # @param values [Array<Object>]
    # @return [Hash{String => Object}]
    def row_from(values)
      columns = [model_class.primary_key.to_sym, *fields]
      columns.map(&:to_s).zip(values).to_h
    end

  protected

    # Builds one relation containing records referenced by any of +fields+.
    #
    # @param model [Class<ApplicationRecord>]
    # @param relation [ActiveRecord::Relation]
    # @param fields [Array<Symbol>]
    # @return [ActiveRecord::Relation]
    def referenced_records(model, relation, *fields)
      fields.map { |field| model.where(id: relation.select(field)) }
            .reduce { |combined, scope| combined.or(scope) }
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
    # @param relations [Hash{Symbol => ActiveRecord::Relation}]
    def initialize(relations)
      @relations = relations.transform_keys(&:to_sym).freeze
    end

    # @param name [String, Symbol]
    # @return [ActiveRecord::Relation]
    def relation_for(name)
      @relations.fetch(name.to_sym)
    end

    # @param name [String, Symbol]
    # @return [Boolean]
    def include?(name)
      @relations.key?(name.to_sym)
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
      @batch_size = Integer(batch_size)
      raise ArgumentError, "batch size must be positive" unless @batch_size.positive?
    end

    # Recursively expands a configured selection into all supporting records.
    # Dependency scopes remain lazy until files are written.
    #
    # @param selection [CourseTransfer::ExportSelection]
    # @return [CourseTransfer::ExportPlan]
    def build_plan(selection)
      dependency_order
      fragments = Hash.new { |hash, name| hash[name] = [] }
      queue = selection.seed_relations.to_a
      visited = Set.new

      until queue.empty?
        name, relation = queue.shift
        name = name.to_sym
        signature = [name, relation.to_sql]
        next unless visited.add?(signature)

        exporter = registry.fetch(name)
        fragments[name] << relation

        exporter.dependencies(relation).each do |dependency_name, dependency_relation|
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

      dependency_order.each do |exporter|
        next unless plan.include?(exporter.name)

        key_maps[exporter.name]
        write_table(exporter, plan.relation_for(exporter.name), key_maps)
      end

      Version.write_manifest!(context, parts: plan.names)
      FileTransfer.export(plan, context:, key_maps:)
      plan
    end

  private

    def write_table(exporter, relation, key_maps)
      path = context.staging_path.join(exporter.filename)
      seen_documents = {}

      File.open(path, "w") do |file|
        each_plucked_row(exporter, relation) do |row|
          document, natural_key = serialize_row(exporter, row, key_maps)
          signature = Serialization.canonical(natural_key)
          canonical_document = Serialization.canonical(document)
          key_maps[exporter.name][row.fetch(exporter.model_class.primary_key)] = natural_key

          if seen_documents.key?(signature)
            unless seen_documents.fetch(signature) == canonical_document
              raise DuplicateNaturalKey,
                    "#{exporter.name} contains conflicting records for #{natural_key.inspect}"
            end
            next
          end

          seen_documents[signature] = canonical_document
          Serialization.dump_document(file, document)
        end
      end
    end

    def each_plucked_row(exporter, relation)
      primary_key = exporter.model_class.primary_key
      scope = relation.reorder(primary_key => :asc)
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
        break if values.length < batch_size
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
      return nil if source_id.nil?
      return source_id if source_id.respond_to?(:negative?) && source_id <= 0

      key_maps.fetch(target_name).fetch(source_id.to_s) do
        key_maps.fetch(target_name).fetch(source_id) do
          raise MissingExportReference,
                "#{target_name} record #{source_id.inspect} was referenced but not exported"
        end
      end
    end

    def dependency_order
      @dependency_order ||= DependencyOrder.new(registry).call
    end
  end
end
