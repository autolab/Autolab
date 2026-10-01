require "fileutils"
require "json"
require_relative "errors"
require_relative "file_transfer"
require_relative "schema"
require_relative "serialization"
require_relative "version"

module CourseTransfer
  class ExportSelection
    attr_reader :course, :users, :assessments

    def initialize(course:, users: nil, assessments: nil)
      @course = course
      @users = users || User.none
      @assessments = assessments || Assessment.none
    end

    def seed_relations
      selected_assessments = Assessment.where(course_id: course.id, id: assessments.select(:id))
      selected_memberships = CourseUserDatum.where(
        course_id: course.id, user_id: users.select(:id)
      )
      selected_users = User.where(id: selected_memberships.select(:user_id))

      {
        courses: Course.where(id: course.id),
        users: selected_users,
        course_user_data: selected_memberships,
        assessments: selected_assessments,
        submissions: Submission.where(
          assessment_id: selected_assessments.select(:id),
          course_user_datum_id: selected_memberships.select(:id)
        ),
        assessment_user_data: AssessmentUserDatum.where(
          assessment_id: selected_assessments.select(:id),
          course_user_datum_id: selected_memberships.select(:id)
        ),
        extensions: Extension.where(
          assessment_id: selected_assessments.select(:id),
          course_user_datum_id: selected_memberships.select(:id)
        )
      }
    end
  end

  class ExportManager
    PREVIEW_FILENAME = "preview.json".freeze

    attr_reader :context

    def initialize(context:)
      @context = context
    end

    def build_relations(selection)
      fragments = Hash.new { |hash, name| hash[name] = [] }
      queue = selection.seed_relations.to_a
      visited = Set.new

      until queue.empty?
        name, relation = queue.shift
        name = name.to_sym
        next unless visited.add?([name, relation.to_sql])

        table = Schema.fetch(name)
        fragments[name] << relation
        table.dependencies(relation).each { |dependency| queue << dependency }
      end

      fragments.transform_values do |scopes|
        scopes.reduce { |combined, scope| combined.or(scope) }
      end
    end

    def export(relations)
      FileUtils.mkdir_p(context.staging_path)
      id_maps = Hash.new { |hash, name| hash[name] = {} }

      Schema.each do |table|
        next unless relations.key?(table.name)

        write_table(table, relations.fetch(table.name), id_maps)
      end

      write_preview(relations, id_maps)
      Version.write_manifest!(context, parts: relations.keys)
      FileTransfer.export(relations, context:, id_maps:)
      relations
    end

  private

    def write_table(table, relation, id_maps)
      path = context.staging_path.join(table.filename)
      rows = relation.reorder(table.model_class.primary_key => :asc).pluck(*table.pluck_fields)

      File.open(path, "w") do |file|
        rows.each_with_index do |values, index|
          row = table.row_from(values)
          package_id = index + 1
          id_maps[table.name][row.fetch(table.model_class.primary_key)] = package_id
          Serialization.dump_document(file, serialize_row(table, row, package_id, id_maps))
        end
      end
    end

    def serialize_row(table, row, package_id, id_maps)
      document = { "_id" => package_id }
      table.fields.each do |field|
        value = row.fetch(field.to_s)
        # Host filesystem destinations are deliberately not portable archive data.
        value = nil if table.name == :assessments && field == :remote_handin_path
        target = table.ref_fields[field]
        if target
          missing = table.missing_reference?(field)
          value = reference(
            target,
            value,
            id_maps,
            missing:,
            missing_value: missing ? table.missing_reference_value(field) : nil
          )
        end
        document[field.to_s] = value
      end
      document
    end

    def reference(target, source_id, id_maps, missing: false, missing_value: nil)
      return nil if source_id.nil?
      return source_id if source_id.respond_to?(:negative?) && source_id <= 0

      target_ids = id_maps.fetch(target, {})
      package_id = target_ids[source_id.to_s] || target_ids[source_id]
      return missing_value if package_id.nil? && missing
      if package_id.nil?
        raise MissingExportReference, "#{target} record #{source_id.inspect} was not exported"
      end

      { "table" => target.to_s, "id" => package_id }
    end

    def write_preview(relations, id_maps)
      memberships = relations.fetch(:course_user_data)
                        .pluck(:user_id, :instructor, :course_assistant)
                        .to_h { |user_id, instructor, assistant|
                          role = instructor ? "Instructor" :
                            (assistant ? "Course Assistant (TA)" : "Student")
                          [user_id, role]
                        }
      users = relations.fetch(:users).pluck(:id, :email, :first_name, :last_name).map do |
        id, email, first_name, last_name|
        name = [first_name, last_name].compact.join(" ").strip
        {
          id: id_maps.fetch(:users).fetch(id).to_s,
          name: name.presence || email,
          email:,
          role: memberships.fetch(id, "Student")
        }
      end
      assessments = relations.fetch(:assessments).pluck(:id, :name, :display_name).map do |
        id, name, display_name|
        {
          id: id_maps.fetch(:assessments).fetch(id).to_s,
          name: display_name.presence || name,
          identifier: name
        }
      end

      preview = {
        version: Version::CURRENT,
        users: users.sort_by { |user| [user.fetch(:name).downcase, user.fetch(:email).downcase] },
        assessments: assessments.sort_by { |assessment|
          [assessment.fetch(:name).downcase, assessment.fetch(:identifier).downcase]
        }
      }
      context.staging_path.join(PREVIEW_FILENAME).write(JSON.generate(preview))
    end
  end
end
