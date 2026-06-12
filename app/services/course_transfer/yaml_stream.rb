module CourseTransfer
  # Safely reads a YAML stream containing multiple documents.
  module YamlStream
    # @param contents [String]
    # @param filename [String]
    # @return [Array<Object>]
    def self.load(contents, filename:)
      Psych.parse_stream(contents, filename:).children.map do |document|
        loader = Psych::ClassLoader::Restricted.new([], [])
        scanner = Psych::ScalarScanner.new(loader)
        Psych::Visitors::NoAliasRuby.new(
          scanner,
          loader,
          symbolize_names: false,
          freeze: false
        ).accept(document)
      end
    end
  end
end
