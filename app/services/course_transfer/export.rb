# frozen_string_literal: true

require "fileutils"
require "pathname"
require "yaml"

module CourseTransfer
  # Shared machinery for dependency-based course exports. Individual course
  # parts can define exporters by inheriting from Export::Exporter.
  class Export
    def self.export(exporter, memo: {}, context: nil)
      Runner.new(memo: memo, context: context).export(exporter)
    end

    # Exporters describe one part of the graph. Dependencies are represented
    # as a hash from a dependency key to another exporter, rather than as
    # already-exported values, so the runner can walk the graph in one place.
    class Exporter
      def memo_key(_context: nil)
        raise NotImplementedError, "#{self.class} must implement #memo_key"
      end

      def dependencies(_context: nil)
        {}
      end

      def pre_export_hook(_context: nil)
        # Override when the part needs to be prepared before its dependencies.
      end

      def post_export_hook(_dependencies, _context: nil)
        # Override when the value needs to be finalized after its dependencies.
      end
    end

    # The only method that knows how to traverse the graph. The memo is
    # intentionally supplied by the caller, making it possible to share
    # exported values across multiple roots.
    class Runner
      attr_reader :memo

      def initialize(memo: {}, context: nil)
        @memo = memo
        @context = context
        @visiting = []
      end

      def export(exporter)
        key = exporter.memo_key(_context: @context)
        return memo[key] if !key.nil? && memo.key?(key)

        # A nil memo key disables caching, but the exporter still participates
        # in cycle detection for the duration of this traversal.
        visiting_key = key.nil? ? [:exporter, exporter.object_id] : [:memo_key, key]

        if @visiting.include?(visiting_key)
          cycle = (@visiting.drop_while { |item| item != visiting_key } + [visiting_key]).join(" -> ")
          raise ArgumentError, "cycle detected while exporting: #{cycle}"
        end

        @visiting << visiting_key
        exporter.pre_export_hook(_context: @context)

        dependencies = exporter.dependencies(_context: @context)
        unless dependencies.is_a?(Hash)
          raise ArgumentError, "dependencies must be a Hash of keys to exporters"
        end

        dependency_values = dependencies.each_with_object({}) do |(key, dependency_exporter), values|
          unless dependency_exporter.is_a?(Exporter)
            raise ArgumentError, "dependency values must be CourseTransfer::Export::Exporter objects"
          end

          values[key] = export(dependency_exporter)
        end

        value = exporter.post_export_hook(dependency_values, _context: @context)
        memo[key] = value unless key.nil?
        value
      ensure
        @visiting.delete(visiting_key) if visiting_key
      end
    end

    # A simple value, including a String, still has an exporter so it can
    # participate in the same dependency graph. It remains a Ruby value until
    # the final course/package serializer writes the composed structure.
    class InlineValueExporter < Exporter
      def initialize(value, memo_key: nil)
        super()
        @value = value
        @memo_key = memo_key
      end

      def memo_key(_context: nil)
        @memo_key
      end

      def post_export_hook(_dependency_values, _context: nil)
        @value
      end
    end

    class InlineDependencyExporter < Exporter
      def initialize(memo_key: nil)
        super()
        @memo_key = memo_key
      end

      def memo_key(_context: nil)
        @memo_key
      end

      def post_export_hook(dependency_values, _context: nil)
        dependency_values
      end
    end

    # A larger value can be written to its own YAML file. The value returned to
    # the parent is a natural key that an eventual importer can resolve.
    class FileYamlExporter < Exporter
      def initialize(filename:, memo_key: nil)
        super()
        @filename = filename
        @memo_key = memo_key
      end

      def memo_key(_context: nil)
        @memo_key
      end

      def post_export_hook(dependency_values, _context: nil)
        context = _context
        raise ArgumentError, "a staging_path is required for file exports" unless context&.staging_path

        path = Pathname.new(context.staging_path).join(@filename)
        FileUtils.mkdir_p(path.dirname)
        path.write(YAML.dump(stringify_keys(dependency_values)))

        { "file" => path.relative_path_from(Pathname.new(context.staging_path)).to_s }
      end

      private

      def stringify_keys(value)
        case value
        when Hash
          value.each_with_object({}) do |(key, nested_value), result|
            result[key.to_s] = stringify_keys(nested_value)
          end
        when Array
          value.map { |nested_value| stringify_keys(nested_value) }
        else
          value
        end
      end
    end

    # This is the shape a caller would use from a course exporter:
    #
    #   runner = CourseTransfer::Export::Runner.new(
    #     memo: {}, context: context
    #   )
    #   result = runner.export(course_exporter)
    #
    # Exporting another root with the same runner reuses the memoized value.
  end
end
