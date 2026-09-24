require_relative "errors"
require_relative "serialization"
require_relative "version"

module CourseTransfer
  # Reads the selectable users and assessments from an extracted package.
  class ImportPreview
    Item = Struct.new(:key, :name, :email, :role, keyword_init: true)

    attr_reader :users, :assessments

    def initialize(registry:, context:)
      @registry = registry
      @context = context
      parts = package_parts
      @users = parts.include?(:users) ? read_users : []
      @assessments = parts.include?(:assessments) ? read_assessments : []
    end

  private

    def package_parts
      manifest = Version.read_manifest(@context.staging_path)
      raise InvalidPackage, "manifest.yml is missing" unless manifest

      Version.assert_importable!(
        version: manifest.fetch("version"),
        min_target: manifest.fetch("min_target_version")
      )
      manifest.fetch("parts").map(&:to_sym).to_set
    rescue KeyError => e
      raise InvalidPackage, "manifest is missing #{e.key.inspect}"
    end

    def documents(name)
      exporter = @registry.fetch(name)
      path = @context.staging_path.join(exporter.filename)
      raise InvalidPackage, "#{exporter.filename} is missing" unless path.file?

      File.open(path, "rb") do |input|
        Serialization.each_document(input, filename: exporter.filename).to_a
      end
    rescue Psych::Exception => e
      raise InvalidPackage, "#{exporter.filename} is invalid YAML: #{e.message}"
    end

    def read_users
      roles = membership_roles
      documents(:users).map do |document|
        validate_preview_document!(document, :users)
        email = document.fetch("email").to_s
        name = [document["first_name"], document["last_name"]].compact.join(" ").strip
        Item.new(
          key: Serialization.canonical(document.fetch("_key")),
          name: name.presence || email,
          email:,
          role: roles.fetch(Serialization.canonical(document.fetch("_key")), "Student")
        )
      end.sort_by { |item| [item.name.downcase, item.email.downcase] }
    end

    def read_assessments
      documents(:assessments).map do |document|
        validate_preview_document!(document, :assessments)
        Item.new(
          key: Serialization.canonical(document.fetch("_key")),
          name: document["display_name"].presence || document.fetch("name").to_s,
          email: document.fetch("name").to_s,
          role: nil
        )
      end.sort_by { |item| [item.name.downcase, item.email.downcase] }
    end

    def membership_roles
      return {} unless package_parts.include?(:course_user_data)

      documents(:course_user_data).each_with_object({}) do |document, roles|
        validate_preview_document!(document, :course_user_data)
        reference = document["user_id"]
        next unless reference.is_a?(Hash) && reference["key"]

        role = if document["instructor"]
                 "Instructor"
               elsif document["course_assistant"]
                 "Course Assistant (TA)"
               else
                 "Student"
               end
        roles[Serialization.canonical(reference.fetch("key"))] = role
      end
    end

    def validate_preview_document!(document, name)
      return if document.is_a?(Hash) && document.key?("_key")

      raise InvalidPackage, "#{@registry.fetch(name).filename} contains an invalid row"
    end
  end

  # Computes the subset of package rows required by an import selection.
  class ImportSelection
    attr_reader :included_keys, :documents

    def initialize(registry:, context:, user_keys:, assessment_keys:)
      @registry = registry
      @context = context
      @selected_user_keys = Array(user_keys).map(&:to_s).to_set
      @selected_assessment_keys = Array(assessment_keys).map(&:to_s).to_set
      @documents = load_documents
      @included_keys = Hash.new { |hash, name| hash[name] = Set.new }
      @documents.each_key { |name| @included_keys[name] }
      build!
    end

    def include?(name, document)
      included_keys[name.to_sym].include?(key_for(document))
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

      Version.assert_importable!(
        version: manifest.fetch("version"),
        min_target: manifest.fetch("min_target_version")
      )
      parts = manifest.fetch("parts").map(&:to_sym).to_set
      parts.each { |name| @registry.fetch(name) }
      raise InvalidPackage, "manifest must include courses" unless parts.include?(:courses)

      parts
    rescue UnknownExporter => e
      raise InvalidPackage, e.message
    rescue KeyError => e
      raise InvalidPackage, "manifest is missing #{e.key.inspect}"
    end

    def load_documents
      package_parts.to_h do |name|
        exporter = @registry.fetch(name)
        path = @context.staging_path.join(exporter.filename)
        raise InvalidPackage, "#{exporter.filename} is missing" unless path.file?

        indexed = {}
        File.open(path, "rb") do |input|
          Serialization.each_document(input, filename: exporter.filename).each do |document|
            unless document.is_a?(Hash) && document.key?("_key")
              raise InvalidPackage, "#{exporter.filename} contains an invalid row"
            end

            key = key_for(document)
            if indexed.key?(key) && Serialization.canonical(indexed.fetch(key)) !=
                                    Serialization.canonical(document)
              raise InvalidPackage, "#{exporter.filename} has conflicting rows"
            end

            indexed[key] ||= document
          end
        end
        [name, indexed]
      rescue Psych::Exception => e
        raise InvalidPackage, "#{exporter.filename} is invalid YAML: #{e.message}"
      end
    end

    def build!
      include_matching(:courses) { true }
      include_matching(:users) { |document| @selected_user_keys.include?(key_for(document)) }
      include_matching(:course_user_data) { |document| included_reference?(document, "user_id") }
      include_matching(:assessments) do |document|
        @selected_assessment_keys.include?(key_for(document))
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
        included_keys.each do |name, keys|
          exporter = @registry.fetch(name)
          keys.to_a.each do |key|
            document = documents.fetch(name).fetch(key)
            exporter.ref_fields.each_key do |field|
              reference = document[field.to_s]
              next unless reference.is_a?(Hash) && reference["table"] && reference["key"]

              target = reference.fetch("table").to_sym
              target_key = Serialization.canonical(reference.fetch("key"))
              unless documents.fetch(target, {}).key?(target_key)
                raise MissingImportReference,
                      "reference to missing #{target} #{reference.fetch('key').inspect}"
              end
              changed = included_keys[target].add?(target_key) || changed
            end
          end
        end
        break unless changed
      end
    end

    def include_matching(name)
      documents.fetch(name, {}).each_value do |document|
        included_keys[name] << key_for(document) if yield(document)
      end
    end

    def included_reference?(document, field)
      reference = document[field]
      return false unless reference.is_a?(Hash) && reference["table"] && reference["key"]

      included_keys[reference.fetch("table").to_sym].include?(
        Serialization.canonical(reference.fetch("key"))
      )
    end

    def excluded_documents(name)
      documents.fetch(name, {}).reject { |key, _| included_keys[name].include?(key) }.values
    end

    def key_for(document)
      Serialization.canonical(document.fetch("_key"))
    end
  end
end
