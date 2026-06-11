module CourseTransfer
  class ImportError < StandardError; end
  class CyclicImportDependencies < ImportError; end

  # Determines a stable order in which each table can be inserted with its
  # foreign keys already resolved. Only explicitly deferred references are
  # omitted from this ordering.
  class ImportOrder
    def initialize(registry)
      @registry = registry
    end

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

  # Coordinates package parsing and one-pass, dependency-ordered table inserts.
  # Parsing, natural-key lookup, inserts, validation, and deferred references
  # are phase boundaries only; their implementations will follow later.
  class ImportManager
    attr_reader :registry, :context

    def initialize(registry:, context:)
      @registry = registry
      @context = context
    end

    def import_order
      ImportOrder.new(registry).call
    end

    def import
      ApplicationRecord.transaction do
        package = read_package
        key_maps = preload_existing_natural_keys(package)

        import_order.each do |exporter|
          import_table(exporter, package:, key_maps:)
        end

        resolve_deferred_references(package:, key_maps:)
        validate_import(package:, key_maps:)
        run_other_import_hooks
      end
    end

  private

    def read_package
      raise NotImplementedError, "package loading has not been implemented"
    end

    def preload_existing_natural_keys(_package)
      raise NotImplementedError, "natural-key loading has not been implemented"
    end

    def import_table(_exporter, package:, key_maps:)
      raise NotImplementedError, "table import has not been implemented"
    end

    def resolve_deferred_references(package:, key_maps:)
      raise NotImplementedError, "deferred references have not been implemented"
    end

    def validate_import(package:, key_maps:)
      raise NotImplementedError, "import validation has not been implemented"
    end

    def run_other_import_hooks
      raise NotImplementedError, "other_import hooks have not been implemented"
    end
  end
end
