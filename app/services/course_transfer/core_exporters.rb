require_relative "export"

module CourseTransfer
  # Exporters for the normalized course, assessment, and submission graph.
  module CoreExporters
    # Transfers penalty and tweak rows.
    class ScoreAdjustmentExporter < Exporter
      def initialize
        super(name: :score_adjustments, model_class: ScoreAdjustment)
      end

      # @return [Array<Symbol>]
      def fields
        %i[kind value type]
      end

      # Score adjustments have no owning reference, so their value tuple is the
      # only portable identity available in the current schema.
      # @return [Array<Symbol>]
      def key_fields
        %i[type kind value]
      end

      # Identical immutable adjustment values may safely be shared on import.
      # @return [Boolean]
      def reuse_existing?
        true
      end
    end

    # Transfers safe, non-authentication user profile fields.
    class UserExporter < Exporter
      def initialize
        super(name: :users, model_class: User)
      end

      # Authentication credentials, tokens, sign-in history, administrator
      # status, and host-specific Unix usernames are deliberately excluded.
      # @return [Array<Symbol>]
      def fields
        %i[email first_name last_name created_at updated_at school major year
           hover_assessment_date]
      end

      # @return [Array<Symbol>]
      def key_fields
        %i[email]
      end

      # @param field [Symbol]
      # @param value [Object]
      # @return [Object]
      def normalize_key_value(field, value)
        field == :email ? value.to_s.downcase : value
      end

      # Existing global accounts are reused by email.
      # @return [Boolean]
      def reuse_existing?
        true
      end
    end

    # Transfers the root course configuration row.
    class CourseExporter < Exporter
      def initialize
        super(name: :courses, model_class: Course)
      end

      # @return [Array<Symbol>]
      def fields
        %i[name semester late_slack grace_days display_name start_date end_date
           disabled exam_in_progress version_threshold late_penalty_id
           version_penalty_id cgdub_dependencies_updated_at gb_message website
           access_code disable_on_end]
      end

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

      # @return [Hash{Symbol => Symbol}]
      def ref_fields
        {
          late_penalty_id: :score_adjustments,
          version_penalty_id: :score_adjustments
        }
      end

      # @return [Array<Symbol>]
      def key_fields
        %i[name]
      end

      # @param field [Symbol]
      # @param value [Object]
      # @return [Object]
      def normalize_key_value(field, value)
        field == :name ? value.to_s.downcase : value
      end

      # Maps files rooted directly in the course directory. Assessment folders
      # are owned by AssessmentExporter, so they are excluded here.
      #
      # @param relation [ActiveRecord::Relation<Course>]
      # @param direction [:export, :import]
      # @return [Array<CourseTransfer::FileMapping>]
      def file_mappings(relation, direction:)
        relation.find_each.flat_map do |course|
          excluded = course.assessments.pluck(:name).map do |assessment_name|
            course.directory_path.join(assessment_name)
          end
          excluded << course.directory_path.join("autolab.log")
          FileTransfer.tree_mappings(
            course,
            root: course.directory_path,
            exclude: excluded,
            direction:
          )
        end
      end
    end

    # Transfers course enrollment and role rows.
    class CourseUserDatumExporter < Exporter
      def initialize
        super(name: :course_user_data, model_class: CourseUserDatum)
      end

      # @return [Array<Symbol>]
      def fields
        %i[lecture section grade_policy course_id created_at updated_at instructor
           dropped nickname course_assistant tweak_id user_id course_number]
      end

      # @param relation [ActiveRecord::Relation<CourseUserDatum>]
      # @return [Hash{Symbol => ActiveRecord::Relation}]
      def dependencies(relation)
        {
          users: User.where(id: relation.select(:user_id)),
          score_adjustments: ScoreAdjustment.where(id: relation.select(:tweak_id))
        }
      end

      # @return [Hash{Symbol => Symbol}]
      def ref_fields
        {
          course_id: :courses,
          user_id: :users,
          tweak_id: :score_adjustments
        }
      end

      # @return [Array<Symbol>]
      def key_fields
        %i[course_id user_id]
      end
    end

    # Transfers assessment group identity rows.
    class GroupExporter < Exporter
      def initialize
        super(name: :groups, model_class: Group)
      end

      # Created time scopes otherwise non-unique display names without relying
      # on a source database ID.
      # @return [Array<Symbol>]
      def fields
        %i[name created_at updated_at]
      end

      # @return [Array<Symbol>]
      def key_fields
        %i[name created_at]
      end
    end

    # Transfers assessment configuration rows and discovers problems.
    class AssessmentExporter < Exporter
      def initialize
        super(name: :assessments, model_class: Assessment)
      end

      # @return [Array<Symbol>]
      def fields
        %i[due_at end_at start_at name description created_at updated_at course_id
           display_name handin_filename handin_directory max_grace_days handout
           writeup allow_unofficial max_submissions disable_handins exam max_size
           version_threshold late_penalty_id version_penalty_id quiz quizData
           remote_handin_path category_name group_size embedded_quiz_form_data
           embedded_quiz github_submission_enabled allow_student_assign_group
           is_positive_grading disable_network]
      end

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

      # @return [Hash{Symbol => Symbol}]
      def ref_fields
        {
          course_id: :courses,
          late_penalty_id: :score_adjustments,
          version_penalty_id: :score_adjustments
        }
      end

      # @return [Array<Symbol>]
      def key_fields
        %i[course_id name]
      end

      # @param field [Symbol]
      # @param value [Object]
      # @return [Object]
      def normalize_key_value(field, value)
        field == :name ? value.to_s.downcase : value
      end

      # Maps all assessment-directory files outside the handin directory.
      #
      # @param relation [ActiveRecord::Relation<Assessment>]
      # @param direction [:export, :import]
      # @return [Array<CourseTransfer::FileMapping>]
      def file_mappings(relation, direction:)
        relation.find_each.flat_map do |assessment|
          exclude = assessment.handin_directory.present? ? [assessment.handin_directory_path] : []
          FileTransfer.tree_mappings(
            assessment,
            root: assessment.folder_path,
            exclude:,
            direction:
          )
        end
      end
    end

    # Transfers course and assessment attachment records and contents.
    class AttachmentExporter < Exporter
      def initialize
        super(name: :attachments, model_class: Attachment)
      end

      # @return [Array<Symbol>]
      def fields
        %i[filename mime_type name created_at updated_at course_id assessment_id
           category_name release_at]
      end

      # Course and assessment rows are the records that introduce an
      # attachment into the dependency graph. Returning them here would create
      # a cycle back to those exporters.
      #
      # @return [Hash]
      def dependencies(_relation)
        {}
      end

      # @return [Hash{Symbol => Symbol}]
      def ref_fields
        { course_id: :courses, assessment_id: :assessments }
      end

      # @return [Array<Symbol>]
      def key_fields
        %i[course_id assessment_id name filename release_at]
      end

      # @param relation [ActiveRecord::Relation<Attachment>]
      # @param direction [:export, :import]
      # @return [Array<CourseTransfer::FileMapping>]
      def file_mappings(relation, direction:)
        relation.find_each.filter_map do |attachment|
          if direction == :export
            source = if attachment.attachment_file.attached?
                       FileTransfer::BlobSource.new(attachment)
                     else
                       Rails.root.join("attachments", attachment.filename.to_s)
                     end
            next if source.is_a?(Pathname) && !source.file?

            FileMapping.new(record: attachment, kind: "content", source:)
          else
            FileMapping.new(
              record: attachment,
              kind: "content",
              destination_type: :active_storage
            )
          end
        end
      end
    end

    # Transfers assessment problem definitions.
    class ProblemExporter < Exporter
      def initialize
        super(name: :problems, model_class: Problem)
      end

      # @return [Array<Symbol>]
      def fields
        %i[name description assessment_id created_at updated_at max_score optional starred]
      end

      # @return [Hash{Symbol => Symbol}]
      def ref_fields
        { assessment_id: :assessments }
      end

      # @return [Array<Symbol>]
      def key_fields
        %i[assessment_id name]
      end

      # @param field [Symbol]
      # @param value [Object]
      # @return [Object]
      def normalize_key_value(field, value)
        field == :name ? value.to_s.downcase : value
      end
    end

    # Transfers submission metadata and discovers grading children.
    class SubmissionExporter < Exporter
      def initialize
        super(name: :submissions, model_class: Submission)
      end

      # submitted_by_app_id identifies an external OAuth application and is not
      # portable as part of a course package.
      # @return [Array<Symbol>]
      def fields
        %i[version course_user_datum_id assessment_id filename created_at updated_at
           notes mime_type special_type submitted_by_id autoresult detected_mime_type
           submitter_ip tweak_id ignored dave embedded_quiz_form_answer group_key
           jobid missing_problems]
      end

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

      # @return [Hash{Symbol => Symbol}]
      def ref_fields
        {
          course_user_datum_id: :course_user_data,
          assessment_id: :assessments,
          submitted_by_id: :course_user_data,
          tweak_id: :score_adjustments
        }
      end

      # @return [Array<Symbol>]
      def key_fields
        %i[assessment_id course_user_datum_id version]
      end

      # Maps live submission, annotation, and autograder feedback files.
      #
      # @param relation [ActiveRecord::Relation<Submission>]
      # @param direction [:export, :import]
      # @return [Array<CourseTransfer::FileMapping>]
      def file_mappings(relation, direction:)
        relation.find_each.flat_map do |submission|
          next [] unless submission.filename.present? &&
                         submission.assessment.handin_directory.present?

          paths = {
            "handin" => if direction == :export
                          submission.handin_file_path
                        else
                          submission.new_handin_file_path
                        end,
            "annotated" => if direction == :export
                             submission.handin_annotated_file_path
                           else
                             File.join(
                               submission.assessment.handin_directory_path,
                               submission.course_user_datum.email,
                               "annotated_#{submission.filename}"
                             )
                           end,
            "autograde_feedback" => if direction == :export
                                      submission.autograde_feedback_path
                                    else
                                      submission.new_autograde_feedback_path
                                    end
          }

          paths.map do |kind, path|
            if direction == :export
              FileMapping.new(record: submission, kind:, source: path)
            else
              FileMapping.new(
                record: submission,
                kind:,
                destination: path,
                destination_root: submission.assessment.handin_directory_path
              )
            end
          end
        end
      end
    end

    # Transfers per-user assessment state and latest-submission references.
    class AssessmentUserDatumExporter < Exporter
      def initialize
        super(name: :assessment_user_data, model_class: AssessmentUserDatum)
      end

      # @return [Array<Symbol>]
      def fields
        %i[course_user_datum_id assessment_id latest_submission_id created_at
           updated_at grade_type group_id membership_status version_number]
      end

      # @param relation [ActiveRecord::Relation<AssessmentUserDatum>]
      # @return [Hash{Symbol => ActiveRecord::Relation}]
      def dependencies(relation)
        {
          submissions: Submission.where(id: relation.select(:latest_submission_id)),
          groups: Group.where(id: relation.select(:group_id))
        }
      end

      # @return [Hash{Symbol => Symbol}]
      def ref_fields
        {
          course_user_datum_id: :course_user_data,
          assessment_id: :assessments,
          latest_submission_id: :submissions,
          group_id: :groups
        }
      end

      # @return [Array<Symbol>]
      def key_fields
        %i[course_user_datum_id assessment_id]
      end
    end

    # Transfers per-user assessment extensions.
    class ExtensionExporter < Exporter
      def initialize
        super(name: :extensions, model_class: Extension)
      end

      # @return [Array<Symbol>]
      def fields
        %i[course_user_datum_id assessment_id days infinite]
      end

      # @return [Hash{Symbol => Symbol}]
      def ref_fields
        {
          course_user_datum_id: :course_user_data,
          assessment_id: :assessments
        }
      end

      # @return [Array<Symbol>]
      def key_fields
        %i[course_user_datum_id assessment_id]
      end
    end

    # Transfers per-problem submission scores.
    class ScoreExporter < Exporter
      def initialize
        super(name: :scores, model_class: Score)
      end

      # @return [Array<Symbol>]
      def fields
        %i[submission_id score feedback problem_id created_at updated_at released grader_id]
      end

      # @param relation [ActiveRecord::Relation<Score>]
      # @return [Hash{Symbol => ActiveRecord::Relation}]
      def dependencies(relation)
        { course_user_data: CourseUserDatum.where(id: relation.select(:grader_id)) }
      end

      # @return [Hash{Symbol => Symbol}]
      def ref_fields
        {
          submission_id: :submissions,
          problem_id: :problems,
          grader_id: :course_user_data
        }
      end

      # @return [Array<Symbol>]
      def key_fields
        %i[submission_id problem_id]
      end
    end

    # Transfers source annotations attached to submissions and problems.
    class AnnotationExporter < Exporter
      def initialize
        super(name: :annotations, model_class: Annotation)
      end

      # @return [Array<Symbol>]
      def fields
        %i[submission_id filename position line created_at updated_at submitted_by
           comment value problem_id coordinate shared_comment global_comment]
      end

      # @return [Hash{Symbol => Symbol}]
      def ref_fields
        {
          submission_id: :submissions,
          problem_id: :problems
        }
      end

      # No table references annotations, but a content key still permits
      # duplicate detection and deterministic round trips.
      # @return [Array<Symbol>]
      def key_fields
        %i[submission_id problem_id filename position line coordinate submitted_by
           comment value created_at]
      end
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
