require_relative "export"

module CourseTransfer
  # Exporters for the normalized course, assessment, and submission graph.
  module CoreExporters
    # Transfers penalty and tweak rows.
    class ScoreAdjustmentExporter < Exporter
      table :score_adjustments, ScoreAdjustment
      export_fields :kind, :value, :type
      natural_key :type, :kind, :value
      reuse_existing
    end

    # Transfers safe, non-authentication user profile fields.
    class UserExporter < Exporter
      table :users, User
      export_fields :email, :first_name, :last_name, :created_at, :updated_at,
                    :school, :major, :year, :hover_assessment_date
      natural_key :email, case_insensitive: :email
      reuse_existing

      def records_matching(field, values)
        return super unless field == :email

        model_class.where("LOWER(email) IN (?)", values.map { |value| value.to_s.downcase })
      end
    end

    # Transfers the root course configuration row.
    class CourseExporter < Exporter
      table :courses, Course
      export_fields :name, :semester, :late_slack, :grace_days, :display_name,
                    :start_date, :end_date, :disabled, :exam_in_progress,
                    :version_threshold, :late_penalty_id, :version_penalty_id,
                    :cgdub_dependencies_updated_at, :gb_message, :website,
                    :access_code, :disable_on_end
      references late_penalty_id: :score_adjustments,
                 version_penalty_id: :score_adjustments
      natural_key :name, case_insensitive: :name

      # @param relation [ActiveRecord::Relation<Course>]
      # @return [Hash{Symbol => ActiveRecord::Relation}]
      def dependencies(relation)
        adjustments = ScoreAdjustment.where(id: relation.select(:late_penalty_id))
                                     .or(
                                       ScoreAdjustment.where(
                                         id: relation.select(:version_penalty_id)
                                       )
                                     )
        {
          score_adjustments: adjustments,
          attachments: Attachment.where(
            course_id: relation.select(:id),
            assessment_id: nil
          )
        }
      end

      # Maps files rooted directly in the course directory. Assessment folders
      # are owned by AssessmentExporter, so they are excluded here.
      #
      # @param relation [ActiveRecord::Relation<Course>]
      # @return [Array<CourseTransfer::FileMapping>]
      def file_mappings(relation)
        relation.includes(:assessments).find_each.map do |course|
          excluded = course.assessments.map(&:name).map do |assessment_name|
            course.directory_path.join(assessment_name)
          end
          excluded << course.directory_path.join("autolab.log")
          FileMapping.tree(
            course,
            course.directory_path,
            within: Rails.root.join("courses"),
            exclude: excluded
          )
        end
      end
    end

    # Transfers course enrollment and role rows.
    class CourseUserDatumExporter < Exporter
      table :course_user_data, CourseUserDatum
      export_fields :lecture, :section, :grade_policy, :course_id, :created_at,
                    :updated_at, :instructor, :dropped, :nickname,
                    :course_assistant, :tweak_id, :user_id, :course_number
      references course_id: :courses, user_id: :users,
                 tweak_id: :score_adjustments
      natural_key :course_id, :user_id

      # @param relation [ActiveRecord::Relation<CourseUserDatum>]
      # @return [Hash{Symbol => ActiveRecord::Relation}]
      def dependencies(relation)
        {
          users: User.where(id: relation.select(:user_id)),
          score_adjustments: ScoreAdjustment.where(id: relation.select(:tweak_id))
        }
      end
    end

    # Transfers assessment group identity rows.
    class GroupExporter < Exporter
      table :groups, Group
      export_fields :name, :created_at, :updated_at
      natural_key :name, :created_at
    end

    # Transfers assessment configuration rows and discovers problems.
    class AssessmentExporter < Exporter
      table :assessments, Assessment
      export_fields :due_at, :end_at, :start_at, :name, :description, :created_at,
                    :updated_at, :course_id, :display_name, :handin_filename,
                    :handin_directory, :max_grace_days, :handout, :writeup,
                    :allow_unofficial, :max_submissions, :disable_handins, :exam,
                    :max_size, :version_threshold, :late_penalty_id,
                    :version_penalty_id, :quiz, :quizData, :remote_handin_path,
                    :category_name, :group_size, :embedded_quiz_form_data,
                    :embedded_quiz, :github_submission_enabled,
                    :allow_student_assign_group, :is_positive_grading,
                    :disable_network
      references course_id: :courses, late_penalty_id: :score_adjustments,
                 version_penalty_id: :score_adjustments
      natural_key :course_id, :name, case_insensitive: :name

      # @param relation [ActiveRecord::Relation<Assessment>]
      # @return [Hash{Symbol => ActiveRecord::Relation}]
      def dependencies(relation)
        adjustments = ScoreAdjustment.where(id: relation.select(:late_penalty_id))
                                     .or(
                                       ScoreAdjustment.where(
                                         id: relation.select(:version_penalty_id)
                                       )
                                     )
        {
          score_adjustments: adjustments,
          problems: Problem.where(assessment_id: relation.select(:id)),
          attachments: Attachment.where(assessment_id: relation.select(:id))
        }
      end

      # Maps all assessment-directory files outside the handin directory.
      #
      # @param relation [ActiveRecord::Relation<Assessment>]
      # @return [Array<CourseTransfer::FileMapping>]
      def file_mappings(relation)
        relation.includes(:course).find_each.map do |assessment|
          exclude = assessment.handin_directory.present? ? [assessment.handin_directory_path] : []
          FileMapping.tree(
            assessment,
            assessment.folder_path,
            within: assessment.course.directory_path,
            exclude:
          )
        end
      end
    end

    # Transfers course and assessment attachment records and contents.
    class AttachmentExporter < Exporter
      table :attachments, Attachment
      export_fields :filename, :mime_type, :name, :created_at, :updated_at,
                    :course_id, :assessment_id, :category_name, :release_at
      references course_id: :courses, assessment_id: :assessments
      natural_key :course_id, :assessment_id, :name, :filename, :release_at

      # @param relation [ActiveRecord::Relation<Attachment>]
      # @return [Array<CourseTransfer::FileMapping>]
      def file_mappings(relation)
        relation.includes(attachment_file_attachment: :blob).find_each.map do |attachment|
          FileMapping.active_storage(
            attachment,
            attachment.attachment_file,
            fallback: Rails.root.join("attachments", attachment.filename.to_s),
            within: Rails.root.join("attachments")
          )
        end
      end
    end

    # Transfers assessment problem definitions.
    class ProblemExporter < Exporter
      table :problems, Problem
      export_fields :name, :description, :assessment_id, :created_at,
                    :updated_at, :max_score, :optional, :starred
      references assessment_id: :assessments
      natural_key :assessment_id, :name, case_insensitive: :name
    end

    # Transfers submission metadata and discovers grading children.
    class SubmissionExporter < Exporter
      table :submissions, Submission
      export_fields :version, :course_user_datum_id, :assessment_id, :filename,
                    :created_at, :updated_at, :notes, :mime_type, :special_type,
                    :submitted_by_id, :autoresult, :detected_mime_type,
                    :submitter_ip, :tweak_id, :ignored, :dave,
                    :embedded_quiz_form_answer, :group_key, :jobid,
                    :missing_problems
      references course_user_datum_id: :course_user_data,
                 assessment_id: :assessments,
                 submitted_by_id: :course_user_data,
                 tweak_id: :score_adjustments
      natural_key :assessment_id, :course_user_datum_id, :version

      # @param relation [ActiveRecord::Relation<Submission>]
      # @return [Hash{Symbol => ActiveRecord::Relation}]
      def dependencies(relation)
        memberships = CourseUserDatum.where(id: relation.select(:course_user_datum_id))
                                     .or(
                                       CourseUserDatum.where(
                                         id: relation.select(:submitted_by_id)
                                       )
                                     )
        {
          course_user_data: memberships,
          assessments: Assessment.where(id: relation.select(:assessment_id)),
          score_adjustments: ScoreAdjustment.where(id: relation.select(:tweak_id)),
          scores: Score.where(submission_id: relation.select(:id)),
          annotations: Annotation.where(submission_id: relation.select(:id))
        }
      end

      # Maps live submission, annotation, and autograder feedback files.
      #
      # @param relation [ActiveRecord::Relation<Submission>]
      # @return [Array<CourseTransfer::FileMapping>]
      def file_mappings(relation)
        relation.includes(:assessment, course_user_datum: :user).find_each.flat_map do |submission|
          next [] unless submission.filename.present? &&
                         submission.assessment.handin_directory.present?

          root = submission.assessment.handin_directory_path
          {
            "handin" => submission.handin_file_path,
            "annotated" => submission.handin_annotated_file_path,
            "autograde_feedback" => submission.autograde_feedback_path
          }.map do |name, path|
            FileMapping.file(
              submission,
              name,
              path,
              root:,
              within: submission.assessment.folder_path
            )
          end
        end
      end
    end

    # Transfers per-user assessment state and latest-submission references.
    class AssessmentUserDatumExporter < Exporter
      table :assessment_user_data, AssessmentUserDatum
      export_fields :course_user_datum_id, :assessment_id, :latest_submission_id,
                    :created_at, :updated_at, :grade_type, :group_id,
                    :membership_status, :version_number
      references course_user_datum_id: :course_user_data,
                 assessment_id: :assessments, latest_submission_id: :submissions,
                 group_id: :groups
      natural_key :course_user_datum_id, :assessment_id

      # @param relation [ActiveRecord::Relation<AssessmentUserDatum>]
      # @return [Hash{Symbol => ActiveRecord::Relation}]
      def dependencies(relation)
        {
          submissions: Submission.where(id: relation.select(:latest_submission_id)),
          groups: Group.where(id: relation.select(:group_id))
        }
      end
    end

    # Transfers per-user assessment extensions.
    class ExtensionExporter < Exporter
      table :extensions, Extension
      export_fields :course_user_datum_id, :assessment_id, :days, :infinite
      references course_user_datum_id: :course_user_data,
                 assessment_id: :assessments
      natural_key :course_user_datum_id, :assessment_id
    end

    # Transfers per-problem submission scores.
    class ScoreExporter < Exporter
      table :scores, Score
      export_fields :submission_id, :score, :feedback, :problem_id, :created_at,
                    :updated_at, :released, :grader_id
      references submission_id: :submissions, problem_id: :problems,
                 grader_id: :course_user_data
      natural_key :submission_id, :problem_id

      # @param relation [ActiveRecord::Relation<Score>]
      # @return [Hash{Symbol => ActiveRecord::Relation}]
      def dependencies(relation)
        { course_user_data: CourseUserDatum.where(id: relation.select(:grader_id)) }
      end
    end

    # Transfers source annotations attached to submissions and problems.
    class AnnotationExporter < Exporter
      table :annotations, Annotation
      export_fields :submission_id, :filename, :position, :line, :created_at,
                    :updated_at, :submitted_by, :comment, :value, :problem_id,
                    :coordinate, :shared_comment, :global_comment
      references submission_id: :submissions, problem_id: :problems
      natural_key :submission_id, :problem_id, :filename, :position, :line,
                  :coordinate, :submitted_by, :comment, :value, :created_at
    end

    # Builds the registry in foreign-key-safe import/export order.
    #
    # @return [CourseTransfer::ExportRegistry]
    def self.registry
      ExportRegistry.new
                    .register(ScoreAdjustmentExporter.new)
                    .register(UserExporter.new)
                    .register(CourseExporter.new)
                    .register(CourseUserDatumExporter.new)
                    .register(GroupExporter.new)
                    .register(AssessmentExporter.new)
                    .register(AttachmentExporter.new)
                    .register(ProblemExporter.new)
                    .register(SubmissionExporter.new)
                    .register(AssessmentUserDatumExporter.new)
                    .register(ExtensionExporter.new)
                    .register(ScoreExporter.new)
                    .register(AnnotationExporter.new)
    end
  end
end
