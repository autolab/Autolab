require "bigdecimal"
require "json"

module CourseTransfer
  # Canonicalizes values and streams one JSON document per line.
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

    # @param output [IO]
    # @param document [Object]
    # @return [void]
    def dump_document(output, document)
      output.puts(JSON.generate(normalize(document)))
    end

    # Streams safely loaded documents without materializing the whole file.
    #
    # @param input [IO, String]
    # @param filename [String]
    # @return [Enumerator<Object>]
    def each_document(input, filename:)
      return enum_for(__method__, input, filename:) unless block_given?

      input.each_line.with_index(1) do |line, line_number|
        yield JSON.parse(line)
      rescue JSON::ParserError => e
        raise JSON::ParserError, "#{filename}:#{line_number}: #{e.message}"
      end
    end
  end
end
