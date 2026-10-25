module CourseArchive
  module Selection
    def self.ids(values, available)
      selected = Array(values).reject(&:blank?).map { |value| Integer(value.to_s, 10) }.uniq
      raise Error, "Selection contains unavailable IDs" unless (selected - available).empty?

      selected
    rescue ArgumentError, TypeError
      raise Error, "Selection IDs must be integers"
    end

    def self.from_course(course, user_ids:, assessment_ids:)
      users = ids(user_ids, course.course_user_data.pluck(:user_id))
      assessments = course.assessments.where(id: ids(assessment_ids, course.assessment_ids))
      members = course.course_user_data.where(user_id: users)
      submissions = Submission.where(assessment_id: assessments.select(:id),
                                     course_user_datum_id: members.select(:id))
      assessment_users = AssessmentUserDatum.where(assessment_id: assessments.select(:id),
                                                   course_user_datum_id: members.select(:id))
      adjustments = ScoreAdjustment.where(id: [course.late_penalty_id, course.version_penalty_id])
      adjustments = adjustments.or(ScoreAdjustment.where(id: assessments.select(:late_penalty_id)))
      adjustments = adjustments.or(
        ScoreAdjustment.where(id: assessments.select(:version_penalty_id))
      )
      adjustments = adjustments.or(ScoreAdjustment.where(id: members.select(:tweak_id)))
      adjustments = adjustments.or(ScoreAdjustment.where(id: submissions.select(:tweak_id)))
      attachments = course.attachments
      queries = {
        "score_adjustments" => adjustments,
        "users" => User.where(id: users), "courses" => Course.where(id: course.id),
        "container_images" => course.container_images, "course_user_data" => members,
        "groups" => Group.where(id: assessment_users.select(:group_id)),
        "assessments" => assessments,
        "autograders" => Autograder.where(assessment_id: assessments.select(:id)),
        "scoreboards" => Scoreboard.where(assessment_id: assessments.select(:id)),
        "problems" => Problem.where(assessment_id: assessments.select(:id)),
        "attachments" => attachments.where(assessment_id: nil)
                                    .or(attachments.where(assessment_id: assessments.select(:id))),
        "submissions" => submissions, "assessment_user_data" => assessment_users,
        "extensions" => Extension.where(assessment_id: assessments.select(:id),
                                        course_user_datum_id: members.select(:id)),
        "scores" => Score.where(submission_id: submissions.select(:id)),
        "annotations" => Annotation.where(submission_id: submissions.select(:id))
      }
      rows = TABLES.to_h do |name, model|
        fields = [:_id, *model::COURSE_EXPORT_FIELDS, *model::COURSE_EXPORT_REFERENCES.keys]
        values = queries.fetch(name).reorder(:id).pluck(:id, *fields.drop(1))
        [name, values.map { |row| fields.map(&:to_s).zip(row).to_h }]
      end
      TABLES.each do |name, model|
        rows.fetch(name).each do |row|
          model::COURSE_EXPORT_REFERENCES.each_key do |field|
            next if name == "scores" && field == :grader_id

            value = row[field.to_s]
            row[field.to_s] = nil if value.is_a?(Integer) && value <= 0
          end
        end
      end
      rows.fetch("assessments").each { |row| row["remote_handin_path"] = nil }
      clear_attribution(rows)
    end

    def self.from_rows(rows, user_ids:, assessment_ids:)
      selected = { "courses" => rows.fetch("courses"),
                   "container_images" => rows.fetch("container_images") }
      users = ids(user_ids, rows.fetch("users").pluck("_id"))
      assessments = ids(assessment_ids, rows.fetch("assessments").pluck("_id"))
      selected["users"] = rows.fetch("users").select { |row| users.include?(row["_id"]) }
      selected["assessments"] = rows.fetch("assessments").select do |row|
        assessments.include?(row["_id"])
      end
      selected["course_user_data"] = rows.fetch("course_user_data").select do |row|
        users.include?(row["user_id"])
      end
      members = selected.fetch("course_user_data").pluck("_id").to_set
      %w[submissions assessment_user_data extensions].each do |name|
        selected[name] = rows.fetch(name).select do |row|
          members.include?(row["course_user_datum_id"]) &&
            assessments.include?(row["assessment_id"])
        end
      end
      %w[autograders scoreboards problems attachments].each do |name|
        selected[name] = rows.fetch(name).select do |row|
          (name == "attachments" && row["assessment_id"].nil?) ||
            assessments.include?(row["assessment_id"])
        end
      end
      submissions = selected.fetch("submissions").pluck("_id").to_set
      %w[scores annotations].each do |name|
        selected[name] = rows.fetch(name).select { |row|
          submissions.include?(row["submission_id"])
        }
      end
      groups = selected.fetch("assessment_user_data").pluck("group_id").to_set
      selected["groups"] = rows.fetch("groups").select { |row| groups.include?(row["_id"]) }
      adjustments = %w[courses assessments course_user_data submissions].flat_map do |name|
        selected.fetch(name)
      end.flat_map do |row|
        row.values_at("late_penalty_id", "version_penalty_id", "tweak_id")
      end.to_set
      selected["score_adjustments"] = rows.fetch("score_adjustments").select do |row|
        adjustments.include?(row["_id"])
      end
      clear_attribution(selected)
    end

    def self.clear_attribution(rows)
      members = rows.fetch("course_user_data").pluck("_id").to_set
      rows.fetch("submissions").each do |row|
        row["submitted_by_id"] = nil unless members.include?(row["submitted_by_id"])
      end
      rows.fetch("scores").each do |row|
        grader = row["grader_id"]
        row["grader_id"] = 0 unless [0, -1].include?(grader) || members.include?(grader)
      end
      rows
    end
  end
end
