module CourseTransfer
  class ExportError < StandardError; end
  class UnknownExporter < ExportError; end
  class DuplicateExporter < ExportError; end

  # Describes the file associated with one database table. Concrete exporters
  # declare fields and relationships; the manager owns planning, batching, and
  # writing.
  class Exporter
    attr_reader :name, :model_class, :filename

    # @param name [Symbol] stable package name for this table
    # @param model_class [Class<ApplicationRecord>]
    # @param filename [String]
    def initialize(name:, model_class:, filename: nil)
      @name = name.to_sym
      @model_class = model_class
      @filename = filename || "#{name}.yml"
    end

    # Transforms a relation into relations for records in other table files
    # that must also be exported. This method must remain lazy.
    #
    # @param relation [ActiveRecord::Relation]
    # @return [Hash{Symbol => ActiveRecord::Relation}]
    def dependencies(_relation)
      {}
    end

    # Adds the joins needed to pluck this table's fields and the natural keys
    # of referenced records.
    #
    # @param relation [ActiveRecord::Relation]
    # @return [ActiveRecord::Relation]
    def query(relation)
      relation
    end

    # Returns the qualified SQL fields to pluck. Their order is the row format
    # passed to serialization.
    #
    # @return [Array<String, Symbol>]
    def pluck_fields
      []
    end

    # Maps local foreign-key columns to the exporter containing the referenced
    # table. The referenced exporter's key_fields define the portable value
    # written in place of the database ID.
    #
    # @return [Hash{Symbol => Symbol}]
    def ref_fields
      {}
    end

    # Columns forming this table's natural key. A key may contain foreign-key
    # columns; those components are represented by the referenced table's
    # natural key in the package.
    #
    # @return [Array<Symbol>]
    def key_fields
      []
    end

    # References excluded from the normal import ordering. These are resolved
    # in a small deferred-reference pass for genuinely cyclic relationships.
    #
    # @return [Array<Symbol>]
    def deferred_ref_fields
      []
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

    # Converts one plucked row to the hash written to this table's YAML file.
    # Concrete exporters will implement this once the package representation is
    # finalized.
    def serialize(_values)
      raise NotImplementedError, "#{self.class} must implement #serialize"
    end

    # Converts one parsed package row to non-reference database attributes.
    def import_attributes(_document)
      raise NotImplementedError, "#{self.class} must implement #import_attributes"
    end

    # File/blob export work will be added after table exports are functional.
    def other_export(_relation, context:); end

    # File/blob import work will be added after table imports are functional.
    def other_import(_relation, context:); end
  end

  # Holds the exporter for every table file in a package.
  class ExportRegistry
    include Enumerable

    def initialize
      @exporters = {}
    end

    def register(exporter)
      if @exporters.key?(exporter.name)
        raise DuplicateExporter, "exporter #{exporter.name.inspect} is already registered"
      end

      @exporters[exporter.name] = exporter
      self
    end

    def fetch(name)
      @exporters.fetch(name.to_sym) do
        raise UnknownExporter, "no exporter registered for #{name.inspect}"
      end
    end

    def key?(name)
      @exporters.key?(name.to_sym)
    end

    def each(&block)
      @exporters.each_value(&block)
    end

    def names
      @exporters.keys
    end
  end

  # Immutable result of dependency discovery. Relations stay lazy until the
  # manager writes their corresponding files.
  class ExportPlan
    include Enumerable

    def initialize(relations)
      @relations = relations.transform_keys(&:to_sym).freeze
    end

    def relation_for(name)
      @relations.fetch(name.to_sym)
    end

    def each(&block)
      @relations.each(&block)
    end

    def names
      @relations.keys
    end
  end

  # Coordinates dependency discovery and one-file-per-table export. Database
  # querying and YAML writing intentionally remain unimplemented for now.
  class ExportManager
    attr_reader :registry, :context

    def initialize(registry:, context:)
      @registry = registry
      @context = context
    end

    # Recursively expands initial relations into the complete lazy export plan.
    # The implementation will need to account for cycles in the discovery
    # graph without loading every relation merely to test membership.
    def build_plan(_initial_relations)
      raise NotImplementedError, "dependency planning has not been implemented"
    end

    # Writes each planned relation to its exporter's table file, then invokes
    # relation-level auxiliary hooks.
    def export(_plan)
      raise NotImplementedError, "table-file export has not been implemented"
    end
  end
end
