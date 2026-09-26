require_relative "errors"
require_relative "schema"
require_relative "serialization"
require_relative "version"

module CourseTransfer
  # Computes the subset of package rows required by an import selection.
  class ImportSelection
    attr_reader :included_ids, :documents, :parts

    def initialize(context:, user_ids:, assessment_ids:)
      @context = context
      @all_users = user_ids.nil?
      @all_assessments = assessment_ids.nil?
      @selected_user_ids = selected_ids(user_ids)
      @selected_assessment_ids = selected_ids(assessment_ids)
      @parts = package_parts
      @documents = load_documents
      @included_ids = Hash.new { |hash, name| hash[name] = Set.new }
      @documents.each_key { |name| @included_ids[name] }
      build!
    end

    def include?(name, document)
      included_ids[name.to_sym].include?(id_for(document))
    end

    def excluded_assessment_names
      excluded_documents(:assessments).filter_map { |document| document["name"] }
    end

    def excluded_user_emails
      excluded_documents(:users).filter_map { |document| document["email"] }
    end

    def attachment_documents
      documents.fetch(:attachments, {}).values
    end

  private

    def package_parts
      manifest = Version.read_manifest(@context.staging_path)
      raise InvalidPackage, "manifest.yml is missing" unless manifest

      Version.assert_importable!(manifest.fetch("version"))
      parts = manifest.fetch("parts").map(&:to_sym).to_set
      parts.each { |name| Schema.fetch(name) }
      raise InvalidPackage, "manifest must include courses" unless parts.include?(:courses)

      parts
    rescue KeyError => e
      raise InvalidPackage, "invalid manifest entry: #{e.message}"
    end

    def load_documents
      parts.to_h do |name|
        table = Schema.fetch(name)
        path = @context.staging_path.join(table.filename)
        raise InvalidPackage, "#{table.filename} is missing" unless path.file?

        indexed = {}
        File.open(path, "rb") do |input|
          stream = Serialization.each_document(input, filename: table.filename)
          stream.each_with_index do |document, index|
            unless document.is_a?(Hash) && document["_id"].is_a?(Integer) &&
                   document["_id"].positive?
              raise InvalidPackage, "#{table.filename} contains an invalid row"
            end

            id = id_for(document)
            expected_id = index + 1
            unless id == expected_id
              raise InvalidPackage,
                    "#{table.filename} expected _id #{expected_id}, got #{id.inspect}"
            end

            indexed[id] = document
          end
        end
        [name, indexed]
      rescue Psych::Exception => e
        raise InvalidPackage, "#{table.filename} is invalid YAML: #{e.message}"
      end
    end

    def build!
      include_matching(:courses) { true }
      include_matching(:users) do |document|
        @all_users || @selected_user_ids.include?(id_for(document))
      end
      include_matching(:course_user_data) { |document| included_reference?(document, "user_id") }
      include_matching(:assessments) do |document|
        @all_assessments || @selected_assessment_ids.include?(id_for(document))
      end
      include_matching(:submissions) do |document|
        included_reference?(document, "course_user_datum_id") &&
          included_reference?(document, "assessment_id")
      end
      %i[assessment_user_data extensions].each do |name|
        include_matching(name) do |document|
          included_reference?(document, "course_user_datum_id") &&
            included_reference?(document, "assessment_id")
        end
      end
      include_matching(:problems) { |document| included_reference?(document, "assessment_id") }
      include_matching(:attachments) do |document|
        document["assessment_id"].nil? || included_reference?(document, "assessment_id")
      end
      %i[scores annotations].each do |name|
        include_matching(name) { |document| included_reference?(document, "submission_id") }
      end

      # Add records referenced by selected rows (graders, penalties, groups, etc.).
      loop do
        changed = false
        included_ids.each do |name, ids|
          table = Schema.fetch(name)
          ids.to_a.each do |id|
            document = documents.fetch(name).fetch(id)
            table.ref_fields.each_key do |field|
              reference = document[field.to_s]
              next unless reference.is_a?(Hash) && reference["table"] && reference["id"]

              target = reference.fetch("table").to_sym
              target_id = reference.fetch("id")
              unless documents.fetch(target, {}).key?(target_id)
                raise MissingImportReference,
                      "reference to missing #{target} ID #{target_id.inspect}"
              end
              changed = included_ids[target].add?(target_id) || changed
            end
          end
        end
        break unless changed
      end
    end

    def include_matching(name)
      documents.fetch(name, {}).each_value do |document|
        included_ids[name] << id_for(document) if yield(document)
      end
    end

    def included_reference?(document, field)
      reference = document[field]
      return false unless reference.is_a?(Hash) && reference["table"] && reference["id"]

      included_ids[reference.fetch("table").to_sym].include?(reference.fetch("id"))
    end

    def excluded_documents(name)
      documents.fetch(name, {}).reject { |id, _| included_ids[name].include?(id) }.values
    end

    def id_for(document)
      document.fetch("_id")
    end

    def selected_ids(values)
      Array(values).filter_map do |value|
        id = value.is_a?(Integer) ? value : Integer(value, 10)
        id if id.positive?
      rescue ArgumentError, TypeError
        nil
      end.to_set
    end
  end
end
