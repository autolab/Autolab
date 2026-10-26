require "bigdecimal"

module CourseArchive
  module Records
    MAX_BYTES = 64 * 1024 * 1024

    def self.write(root, rows)
      root.join("manifest.yml").write({ "format" => FORMAT, "version" => VERSION,
                                        "parts" => TABLES.keys }.to_yaml)
      bytes = 0
      rows.each do |name, records|
        yaml = normalize(records).to_yaml
        bytes += yaml.bytesize
        raise Error, "Course metadata is too large" if bytes > MAX_BYTES

        root.join("#{name}.yml").write(yaml)
      end
      memberships = rows.fetch("course_user_data").index_by { |row| row.fetch("user_id") }
      users = rows.fetch("users").map do |user|
        member = memberships.fetch(user.fetch("_id"))
        role = if member["instructor"]
                 "Instructor"
               elsif member["course_assistant"]
                 "Course Assistant (TA)"
               else
                 "Student"
               end
        name = [user["first_name"], user["last_name"]].compact.join(" ").presence || user["email"]
        { id: user["_id"].to_s, email: user["email"], role:, name: }
      end
      assessments = rows.fetch("assessments").map do |row|
        { id: row["_id"].to_s, name: row["display_name"], identifier: row["name"] }
      end
      root.join("preview.json").write(JSON.generate(version: VERSION, users:, assessments:))
    end

    def self.read(root)
      manifest = YAML.safe_load(root.join("manifest.yml").read, aliases: false)
      unless manifest.is_a?(Hash) && manifest["format"] == FORMAT && manifest["version"] == VERSION
        raise Error, "Unsupported course archive. Export the course again using this version."
      end
      raise Error, "Invalid archive tables" unless manifest["parts"] == TABLES.keys

      paths = TABLES.keys.map { |name| root.join("#{name}.yml") }
      raise Error, "Course metadata is too large" if paths.sum(&:size) > MAX_BYTES

      rows = TABLES.keys.zip(paths.map { |path| YAML.safe_load(path.read, aliases: false) }).to_h
      validate!(rows)
      rows
    rescue Psych::Exception, Errno::ENOENT => e
      raise Error, "Invalid course archive: #{e.message}"
    end

    def self.normalize(value)
      case value
      when Hash then value.transform_values { |item| normalize(item) }
      when Array then value.map { |item| normalize(item) }
      when Time, DateTime, ActiveSupport::TimeWithZone then value.iso8601(6)
      when Date then value.iso8601
      when BigDecimal then value.to_s
      else value
      end
    end

    def self.validate!(rows)
      indexes = TABLES.to_h do |name, model|
        records = rows.fetch(name)
        raise Error, "#{name} must be a YAML array" unless records.is_a?(Array)

        fields = ["_id", *model::COURSE_EXPORT_FIELDS.map(&:to_s),
                  *model::COURSE_EXPORT_REFERENCES.keys.map(&:to_s)]
        records.each do |row|
          next if row.is_a?(Hash) && row.keys.all? { |key| key.is_a?(String) } &&
                  row.keys.sort == fields.sort &&
                  row["_id"].is_a?(Integer) && row["_id"].positive?

          raise Error, "Invalid #{name} row"
        end
        index = records.index_by { |row| row["_id"] }
        raise Error, "Duplicate #{name} ID" unless index.size == records.size

        [name, index]
      end
      raise Error, "Archive must contain one course" unless rows.fetch("courses").one?

      TABLES.each do |name, model|
        rows.fetch(name).each do |row|
          model::COURSE_EXPORT_REFERENCES.each do |field, target|
            value = row.fetch(field.to_s)
            next if value.nil?
            next if name == "scores" && field == :grader_id && [0, -1].include?(value)
            next if value.is_a?(Integer) && indexes.fetch(target.to_s).key?(value)

            raise Error, "#{name}.#{field} references an unavailable #{target} row"
          end
        end
      end
      validate_paths!(rows)
      emails = rows.fetch("users").pluck("email").map(&:downcase)
      raise Error, "Duplicate user email" unless emails.uniq.size == emails.size

      validate_ownership!(rows, indexes)
    end

    def self.validate_ownership!(rows, indexes)
      course_id = rows.fetch("courses").first.fetch("_id")
      %w[course_user_data assessments attachments container_images].each do |name|
        raise Error, "#{name} belongs to another course" unless
          rows.fetch(name).all? { |row| row["course_id"] == course_id }
      end
      rows.fetch("assessment_user_data").each do |row|
        submission = indexes.fetch("submissions")[row["latest_submission_id"]]
        next unless submission
        next if submission.values_at("assessment_id", "course_user_datum_id") ==
                row.values_at("assessment_id", "course_user_datum_id")

        raise Error, "Latest submission belongs to another user or assessment"
      end
      %w[scores annotations].each do |name|
        rows.fetch(name).each do |row|
          submission = indexes.fetch("submissions")[row["submission_id"]]
          problem = indexes.fetch("problems")[row["problem_id"]]
          raise Error, "#{name} has inconsistent submission/problem references" unless
            submission && problem && submission["assessment_id"] == problem["assessment_id"]
        end
      end
    end

    def self.validate_paths!(rows)
      rows.fetch("users").each { |row| Paths.filename!(row["email"]) }
      rows.fetch("assessments").each do |row|
        Paths.identifier!(row["name"])
        Paths.filename!(row["handin_filename"]) if row["handin_filename"].present?
        Paths.relative!(row["handin_directory"]) if row["handin_directory"].present?
        %w[handout writeup].each do |field|
          value = row[field]
          Paths.relative!(value) if value.present? && !Utilities.is_url?(value)
        end
      end
      %w[submissions attachments].each do |name|
        rows.fetch(name).each do |row|
          Paths.filename!(row["filename"]) if row["filename"].present?
        end
      end
      rows.fetch("annotations").each do |row|
        Paths.relative!(row["filename"]) unless row["filename"].nil?
      end
    end
  end
end
