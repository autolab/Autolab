require_relative "errors"

module CourseTransfer
  # Topologically orders exporters by their foreign-key references.
  class DependencyOrder
    def initialize(registry)
      @registry = registry
    end

    # @return [Array<CourseTransfer::Exporter>]
    def call
      @complete = {}
      @visiting = []
      @ordered = []
      @registry.each { |exporter| visit(exporter) }
      @ordered.freeze
    end

  private

    def visit(exporter)
      return if @complete[exporter.name]

      if (start = @visiting.index(exporter.name))
        cycle = @visiting.drop(start) + [exporter.name]
        raise CyclicImportDependencies, "cyclic dependency: #{cycle.join(' -> ')}"
      end

      @visiting << exporter.name
      exporter.import_dependencies.each { |name| visit(@registry.fetch(name)) }
      @visiting.pop
      @complete[exporter.name] = true
      @ordered << exporter
    end
  end
end
