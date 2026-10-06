module CourseTransfer
  Table = Struct.new(
    :name, :model_class, :fields, :ref_fields, :match_fields, :dependency_scope,
    :missing_ref_values,
    keyword_init: true
  ) do
    def filename = "#{name}.yml"

    def pluck_fields
      [model_class.primary_key, *fields].map { |field| "#{model_class.table_name}.#{field}" }
    end

    def row_from(values)
      [model_class.primary_key.to_sym, *fields].map(&:to_s).zip(values).to_h
    end

    def dependencies(relation)
      dependency_scope ? dependency_scope.call(relation) : {}
    end

    def missing_reference?(field)
      missing_ref_values&.key?(field)
    end

    def missing_reference_value(field)
      missing_ref_values.fetch(field)
    end

  end

  module Schema
    def self.referenced(model, relation, *fields)
      fields.map { |field| model.where(id: relation.select(field)) }
            .reduce { |combined, scope| combined.or(scope) }
    end

    TABLES = [
      Table.new(
        name: :score_adjustments, model_class: ScoreAdjustment,
        fields: %i[kind value type], ref_fields: {}, match_fields: %i[type kind value]
      ),
      Table.new(
        name: :users, model_class: User,
        fields: %i[email first_name last_name created_at updated_at school major year
                   hover_assessment_date],
        ref_fields: {}, match_fields: %i[email]
      ),
      Table.new(
        name: :courses, model_class: Course,
        fields: %i[name semester late_slack grace_days display_name start_date end_date disabled
                   exam_in_progress version_threshold late_penalty_id version_penalty_id
                   cgdub_dependencies_updated_at gb_message website access_code disable_on_end],
        ref_fields: { late_penalty_id: :score_adjustments,
                      version_penalty_id: :score_adjustments },
        match_fields: %i[name],
        dependency_scope: lambda { |relation|
          {
            score_adjustments: referenced(
              ScoreAdjustment, relation, :late_penalty_id, :version_penalty_id
            ),
            attachments: Attachment.where(course_id: relation.select(:id), assessment_id: nil),
            container_images: ContainerImage.where(course_id: relation.select(:id))
          }
        }
      ),
      Table.new(
        name: :container_images, model_class: ContainerImage,
        fields: %i[name status image_uri course_id dockerfile_contents created_at updated_at],
        ref_fields: { course_id: :courses }, match_fields: %i[course_id name]
      ),
      Table.new(
        name: :course_user_data, model_class: CourseUserDatum,
        fields: %i[lecture section grade_policy course_id created_at updated_at instructor dropped
                   nickname course_assistant tweak_id user_id course_number],
        ref_fields: { course_id: :courses, user_id: :users,
                      tweak_id: :score_adjustments },
        match_fields: %i[course_id user_id],
        dependency_scope: lambda { |relation|
          {
            users: User.where(id: relation.select(:user_id)),
            score_adjustments: ScoreAdjustment.where(id: relation.select(:tweak_id))
          }
        }
      ),
      Table.new(
        name: :groups, model_class: Group, fields: %i[name created_at updated_at],
        ref_fields: {}, match_fields: %i[name created_at]
      ),
      Table.new(
        name: :assessments, model_class: Assessment,
        fields: %i[due_at end_at start_at name description created_at updated_at course_id
                   display_name handin_filename handin_directory max_grace_days handout writeup
                   allow_unofficial max_submissions disable_handins exam max_size version_threshold
                   late_penalty_id version_penalty_id quiz quizData remote_handin_path category_name
                   group_size embedded_quiz_form_data embedded_quiz github_submission_enabled
                   allow_student_assign_group is_positive_grading disable_network],
        ref_fields: { course_id: :courses, late_penalty_id: :score_adjustments,
                      version_penalty_id: :score_adjustments },
        match_fields: %i[course_id name],
        dependency_scope: lambda { |relation|
          {
            score_adjustments: referenced(
              ScoreAdjustment, relation, :late_penalty_id, :version_penalty_id
            ),
            autograders: Autograder.where(assessment_id: relation.select(:id)),
            scoreboards: Scoreboard.where(assessment_id: relation.select(:id)),
            problems: Problem.where(assessment_id: relation.select(:id)),
            attachments: Attachment.where(assessment_id: relation.select(:id))
          }
        }
      ),
      Table.new(
        name: :autograders, model_class: Autograder,
        fields: %i[assessment_id autograde_timeout autograde_image release_score instance_type],
        ref_fields: { assessment_id: :assessments }, match_fields: %i[assessment_id]
      ),
      Table.new(
        name: :scoreboards, model_class: Scoreboard,
        fields: %i[assessment_id banner colspec include_instructors],
        ref_fields: { assessment_id: :assessments }, match_fields: %i[assessment_id]
      ),
      Table.new(
        name: :attachments, model_class: Attachment,
        fields: %i[filename mime_type name created_at updated_at course_id assessment_id
                   category_name release_at],
        ref_fields: { course_id: :courses, assessment_id: :assessments },
        match_fields: %i[course_id assessment_id name filename release_at]
      ),
      Table.new(
        name: :problems, model_class: Problem,
        fields: %i[name description assessment_id created_at updated_at max_score optional starred],
        ref_fields: { assessment_id: :assessments }, match_fields: %i[assessment_id name]
      ),
      Table.new(
        name: :submissions, model_class: Submission,
        fields: %i[version course_user_datum_id assessment_id filename created_at updated_at notes
                   mime_type special_type submitted_by_id autoresult detected_mime_type submitter_ip
                   tweak_id ignored dave embedded_quiz_form_answer group_key jobid missing_problems],
        ref_fields: { course_user_datum_id: :course_user_data, assessment_id: :assessments,
                      submitted_by_id: :course_user_data, tweak_id: :score_adjustments },
        match_fields: %i[assessment_id course_user_datum_id version],
        missing_ref_values: { submitted_by_id: nil },
        dependency_scope: lambda { |relation|
          {
            course_user_data: CourseUserDatum.where(
              id: relation.select(:course_user_datum_id)
            ),
            assessments: Assessment.where(id: relation.select(:assessment_id)),
            score_adjustments: ScoreAdjustment.where(id: relation.select(:tweak_id)),
            scores: Score.where(submission_id: relation.select(:id)),
            annotations: Annotation.where(submission_id: relation.select(:id))
          }
        }
      ),
      Table.new(
        name: :assessment_user_data, model_class: AssessmentUserDatum,
        fields: %i[course_user_datum_id assessment_id latest_submission_id created_at updated_at
                   grade_type group_id membership_status version_number],
        ref_fields: { course_user_datum_id: :course_user_data, assessment_id: :assessments,
                      latest_submission_id: :submissions, group_id: :groups },
        match_fields: %i[course_user_datum_id assessment_id],
        dependency_scope: lambda { |relation|
          {
            submissions: Submission.where(id: relation.select(:latest_submission_id)),
            groups: Group.where(id: relation.select(:group_id))
          }
        }
      ),
      Table.new(
        name: :extensions, model_class: Extension,
        fields: %i[course_user_datum_id assessment_id days infinite],
        ref_fields: { course_user_datum_id: :course_user_data, assessment_id: :assessments },
        match_fields: %i[course_user_datum_id assessment_id]
      ),
      Table.new(
        name: :scores, model_class: Score,
        fields: %i[submission_id score feedback problem_id created_at updated_at released grader_id],
        ref_fields: { submission_id: :submissions, problem_id: :problems,
                      grader_id: :course_user_data },
        match_fields: %i[submission_id problem_id],
        missing_ref_values: { grader_id: 0 }
      ),
      Table.new(
        name: :annotations, model_class: Annotation,
        fields: %i[submission_id filename position line created_at updated_at submitted_by comment
                   value problem_id coordinate shared_comment global_comment],
        ref_fields: { submission_id: :submissions, problem_id: :problems },
        match_fields: %i[submission_id problem_id filename position line coordinate submitted_by
                         comment value created_at]
      )
    ].freeze

    BY_NAME = TABLES.index_by(&:name).freeze

    def self.each(&block) = TABLES.each(&block)
    def self.names = BY_NAME.keys
    def self.fetch(name) = BY_NAME.fetch(name.to_sym)
  end
end
