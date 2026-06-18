require "bigdecimal"
require "json"
require "psych"
require "yaml"

module CourseTransfer
  # Canonicalizes values and safely reads and writes multi-document YAML.
  module Serialization
  module_function

    # @param value [Object]
    # @return [Object]
    def normalize(value)
      case value
      when BigDecimal then value.to_s
      when ActiveSupport::TimeWithZone, Time, DateTime then value.iso8601(6)
      when Date then value.iso8601
      when Hash then value.sort.to_h.transform_values { |item| normalize(item) }
      when Array then value.map { |item| normalize(item) }
      else value
      end
    end

    # @param value [Object]
    # @return [String]
    def canonical(value)
      JSON.generate(normalize(value))
    end

    # @param output [IO]
    # @param document [Object]
    # @return [void]
    def dump_document(output, document)
      output.write(YAML.dump(normalize(document)))
    end

    # Streams safely loaded documents without materializing the whole file.
    #
    # @param input [IO, String]
    # @param filename [String]
    # @return [Enumerator<Object>]
    def each_document(input, filename:)
      return enum_for(__method__, input, filename:) unless block_given?

      handler = Psych::Handlers::DocumentStream.new do |document|
        loader = Psych::ClassLoader::Restricted.new([], [])
        scanner = Psych::ScalarScanner.new(loader)
        yield Psych::Visitors::NoAliasRuby.new(
          scanner, loader, symbolize_names: false, freeze: false
        ).accept(document)
      end
      Psych::Parser.new(handler).parse(input, filename)
    end
  end
end
