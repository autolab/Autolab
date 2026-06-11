require_relative "export"

module CourseTransfer
  # Initial table-file shells for the core course, assessment, and submission
  # graph. Fields, joins, dependency scopes, and serializers will be filled in
  # exporter by exporter.
  module CoreExporters
    class ScoreAdjustmentExporter < Exporter
      def initialize
        super(name: :score_adjustments, model_class: ScoreAdjustment)
      end
    end

    class UserExporter < Exporter
      def initialize
        super(name: :users, model_class: User)
      end

      def key_fields
        %i[email]
      end
    end

    class CourseExporter < Exporter
      def initialize
        super(name: :courses, model_class: Course)
      end

      def ref_fields
        {
          late_penalty_id: :score_adjustments,
          version_penalty_id: :score_adjustments
        }
      end

      def key_fields
        %i[name]
      end
    end

    class CourseUserDatumExporter < Exporter
      def initialize
        super(name: :course_user_data, model_class: CourseUserDatum)
      end

      def ref_fields
        {
          course_id: :courses,
          user_id: :users,
          tweak_id: :score_adjustments
        }
      end

      def key_fields
        %i[course_id user_id]
      end
    end

    class GroupExporter < Exporter
      def initialize
        super(name: :groups, model_class: Group)
      end
    end

    class AssessmentExporter < Exporter
      def initialize
        super(name: :assessments, model_class: Assessment)
      end

      def ref_fields
        {
          course_id: :courses,
          late_penalty_id: :score_adjustments,
          version_penalty_id: :score_adjustments
        }
      end

      def key_fields
        %i[course_id name]
      end
    end

    class ProblemExporter < Exporter
      def initialize
        super(name: :problems, model_class: Problem)
      end

      def ref_fields
        { assessment_id: :assessments }
      end

      def key_fields
        %i[assessment_id name]
      end
    end

    class SubmissionExporter < Exporter
      def initialize
        super(name: :submissions, model_class: Submission)
      end

      def ref_fields
        {
          course_user_datum_id: :course_user_data,
          assessment_id: :assessments,
          submitted_by_id: :course_user_data,
          tweak_id: :score_adjustments
        }
      end

      def key_fields
        %i[assessment_id course_user_datum_id version]
      end
    end

    class AssessmentUserDatumExporter < Exporter
      def initialize
        super(name: :assessment_user_data, model_class: AssessmentUserDatum)
      end

      def ref_fields
        {
          course_user_datum_id: :course_user_data,
          assessment_id: :assessments,
          latest_submission_id: :submissions,
          group_id: :groups
        }
      end

      def key_fields
        %i[course_user_datum_id assessment_id]
      end
    end

    class ExtensionExporter < Exporter
      def initialize
        super(name: :extensions, model_class: Extension)
      end

      def ref_fields
        {
          course_user_datum_id: :course_user_data,
          assessment_id: :assessments
        }
      end

      def key_fields
        %i[course_user_datum_id assessment_id]
      end
    end

    class ScoreExporter < Exporter
      def initialize
        super(name: :scores, model_class: Score)
      end

      def ref_fields
        {
          submission_id: :submissions,
          problem_id: :problems,
          grader_id: :course_user_data
        }
      end

      def key_fields
        %i[submission_id problem_id]
      end
    end

    class AnnotationExporter < Exporter
      def initialize
        super(name: :annotations, model_class: Annotation)
      end

      def ref_fields
        {
          submission_id: :submissions,
          problem_id: :problems
        }
      end
    end

    def self.registry
      ExportRegistry.new
                    .register(ScoreAdjustmentExporter.new)
                    .register(UserExporter.new)
                    .register(CourseExporter.new)
                    .register(CourseUserDatumExporter.new)
                    .register(GroupExporter.new)
                    .register(AssessmentExporter.new)
                    .register(ProblemExporter.new)
                    .register(SubmissionExporter.new)
                    .register(AssessmentUserDatumExporter.new)
                    .register(ExtensionExporter.new)
                    .register(ScoreExporter.new)
                    .register(AnnotationExporter.new)
    end
  end
end
