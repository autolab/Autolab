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

  class ExportPlan
    def initialize(relations)
      @relations = relations.transform_keys(&:to_sym).freeze
    end

    def relation_for(name) = @relations.fetch(name.to_sym)
    def include?(name) = @relations.key?(name.to_sym)
    def names = @relations.keys
  end

  class ExportManager
    PREVIEW_FILENAME = "preview.json".freeze

    attr_reader :context

    def initialize(context:)
      @context = context
    end

    def build_plan(selection)
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

      ExportPlan.new(
        fragments.transform_values { |scopes| scopes.reduce { |combined, scope| combined.or(scope) } }
      )
    end

    def export(plan)
      FileUtils.mkdir_p(context.staging_path)
      id_maps = Hash.new { |hash, name| hash[name] = {} }

      Schema.each do |table|
        next unless plan.include?(table.name)

        write_table(table, plan.relation_for(table.name), id_maps)
      end

      write_preview(plan, id_maps)
      Version.write_manifest!(context, parts: plan.names)
      FileTransfer.export(plan, context:, id_maps:)
      plan
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
        target = table.ref_fields[field]
        document[field.to_s] = target ? reference(target, value, id_maps) : value
      end
      document
    end

    def reference(target, source_id, id_maps)
      return nil if source_id.nil?
      return source_id if source_id.respond_to?(:negative?) && source_id <= 0

      package_id = id_maps.fetch(target).fetch(source_id.to_s) do
        id_maps.fetch(target).fetch(source_id) do
          raise MissingExportReference, "#{target} record #{source_id.inspect} was not exported"
        end
      end
      { "table" => target.to_s, "id" => package_id }
    end

    def write_preview(plan, id_maps)
      memberships = plan.relation_for(:course_user_data)
                        .pluck(:user_id, :instructor, :course_assistant)
                        .to_h { |user_id, instructor, assistant|
                          role = instructor ? "Instructor" :
                            (assistant ? "Course Assistant (TA)" : "Student")
                          [user_id, role]
                        }
      users = plan.relation_for(:users).pluck(:id, :email, :first_name, :last_name).map do |
        id, email, first_name, last_name|
        name = [first_name, last_name].compact.join(" ").strip
        {
          id: id_maps.fetch(:users).fetch(id).to_s,
          name: name.presence || email,
          email:,
          role: memberships.fetch(id, "Student")
        }
      end
      assessments = plan.relation_for(:assessments).pluck(:id, :name, :display_name).map do |
        id, name, display_name|
        {
          id: id_maps.fetch(:assessments).fetch(id).to_s,
          name: display_name.presence || name,
          identifier: name
        }
      end

      preview = {
        version: context.version,
        users: users.sort_by { |user| [user.fetch(:name).downcase, user.fetch(:email).downcase] },
        assessments: assessments.sort_by { |assessment|
          [assessment.fetch(:name).downcase, assessment.fetch(:identifier).downcase]
        }
      }
      context.staging_path.join(PREVIEW_FILENAME).write(JSON.generate(preview))
    end
  end
end
