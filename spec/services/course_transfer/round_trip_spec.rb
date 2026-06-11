require "rails_helper"
require "tmpdir"
require Rails.root.join("app/services/course_transfer/core_exporters")
require Rails.root.join("app/services/course_transfer/import")

RSpec.describe "normalized course transfer" do
  # These records exercise transfer SQL, not model lifecycle callbacks.
  # rubocop:disable Rails/SkipsModelValidations
  def insert_record(model, attributes)
    model.insert_all!([attributes])
    model.find_by!(attributes)
  end
  # rubocop:enable Rails/SkipsModelValidations

  it "round-trips selected course, user, assessment, submission, and grading rows" do
    late_penalty = insert_record(
      ScoreAdjustment,
      type: "Penalty",
      kind: ScoreAdjustment::POINTS,
      value: 1.5
    )
    version_penalty = insert_record(
      ScoreAdjustment,
      type: "Penalty",
      kind: ScoreAdjustment::PERCENT,
      value: 2.0
    )
    course = insert_record(
      Course,
      name: "transfer-course",
      display_name: "Transfer Course",
      semester: "f26",
      late_slack: 0,
      grace_days: 2,
      start_date: Date.new(2026, 8, 1),
      end_date: Date.new(2026, 12, 1),
      version_threshold: -1,
      late_penalty_id: late_penalty.id,
      version_penalty_id: version_penalty.id
    )
    user = insert_record(
      User,
      email: "transfer@example.com",
      first_name: "Transfer",
      last_name: "Student"
    )
    membership = insert_record(
      CourseUserDatum,
      course_id: course.id,
      user_id: user.id,
      lecture: "A",
      section: "1",
      instructor: false,
      course_assistant: false,
      dropped: false
    )
    assessment = insert_record(
      Assessment,
      course_id: course.id,
      name: "lab",
      display_name: "Lab",
      category_name: "Labs",
      start_at: Time.zone.parse("2026-08-10 12:00:00"),
      due_at: Time.zone.parse("2026-08-20 12:00:00"),
      end_at: Time.zone.parse("2026-08-21 12:00:00"),
      max_size: 1_024,
      max_submissions: 10,
      max_grace_days: 2,
      group_size: 1,
      disable_handins: true,
      github_submission_enabled: true,
      allow_student_assign_group: true,
      is_positive_grading: false,
      disable_network: false
    )
    problem = insert_record(
      Problem,
      assessment_id: assessment.id,
      name: "code",
      description: "Code quality",
      max_score: 10.0,
      optional: false,
      starred: false
    )
    submission = insert_record(
      Submission,
      assessment_id: assessment.id,
      course_user_datum_id: membership.id,
      submitted_by_id: membership.id,
      version: 1,
      filename: "handin.tar",
      notes: "first",
      mime_type: "application/x-tar",
      special_type: 0,
      ignored: false,
      group_key: ""
    )
    group = insert_record(
      Group,
      name: "Team One",
      created_at: Time.zone.parse("2026-08-10 11:00:00"),
      updated_at: Time.zone.parse("2026-08-10 11:00:00")
    )
    assessment_user_datum = insert_record(
      AssessmentUserDatum,
      assessment_id: assessment.id,
      course_user_datum_id: membership.id,
      latest_submission_id: submission.id,
      group_id: group.id,
      grade_type: AssessmentUserDatum::NORMAL,
      membership_status: AssessmentUserDatum::CONFIRMED,
      version_number: 1
    )
    extension = insert_record(
      Extension,
      assessment_id: assessment.id,
      course_user_datum_id: membership.id,
      days: 1,
      infinite: false
    )
    score = insert_record(
      Score,
      submission_id: submission.id,
      problem_id: problem.id,
      grader_id: 0,
      score: 9.0,
      feedback: "good",
      released: true
    )
    annotation = insert_record(
      Annotation,
      submission_id: submission.id,
      problem_id: problem.id,
      filename: "main.c",
      position: 1,
      line: 4,
      comment: "nice",
      value: 0.5,
      coordinate: "1,4",
      submitted_by: user.email,
      shared_comment: false,
      global_comment: false,
      created_at: Time.zone.parse("2026-08-20 10:00:00")
    )

    Dir.mktmpdir("course-transfer-spec-") do |directory|
      export_context = CourseTransfer::Context.new(
        staging_path: directory,
        course:,
        version: CourseTransfer::Version::CURRENT,
        mode: :export,
        selected_parts: []
      )
      registry = CourseTransfer::CoreExporters.registry
      export_manager = CourseTransfer::ExportManager.new(registry:, context: export_context)
      selection = CourseTransfer::ExportSelection.new(
        course:,
        users: User.where(id: user.id),
        assessments: Assessment.where(id: assessment.id)
      )

      plan = export_manager.build_plan(selection)
      export_manager.export(plan)

      adjustment_yaml = Pathname.new(directory).join("score_adjustments.yml").read
      expect(adjustment_yaml.scan(/^---$/).size).to eq(2)
      expect(YAML.load_stream(adjustment_yaml).size).to eq(2)
      expect(adjustment_yaml).not_to include("records:")

      exported_submissions = YAML.load_stream(
        Pathname.new(directory).join("submissions.yml").read
      )
      expect(exported_submissions.size).to eq(1)
      exported_submission = exported_submissions.first
      expect(exported_submission.fetch("assessment_id")).to include(
        "table" => "assessments",
        "key" => {
          "course_id" => { "name" => "transfer-course" },
          "name" => "lab"
        }
      )

      Annotation.where(id: annotation.id).delete_all
      Score.where(id: score.id).delete_all
      Extension.where(id: extension.id).delete_all
      AssessmentUserDatum.where(id: assessment_user_datum.id).delete_all
      Submission.where(id: submission.id).delete_all
      Problem.where(id: problem.id).delete_all
      Group.where(id: group.id).delete_all
      CourseUserDatum.where(id: membership.id).delete_all
      Assessment.where(id: assessment.id).delete_all
      Course.where(id: course.id).delete_all
      User.where(id: user.id).delete_all

      import_context = CourseTransfer::Context.new(
        staging_path: directory,
        course: nil,
        version: CourseTransfer::Version::CURRENT,
        mode: :import,
        selected_parts: [],
        course_identifier: "imported-transfer-course",
        instructor_email: "new-instructor@example.com"
      )
      imported_course = CourseTransfer::ImportManager.new(
        registry: CourseTransfer::CoreExporters.registry,
        context: import_context
      ).import

      imported_user = User.find_by!(email: "transfer@example.com")
      imported_instructor = User.find_by!(email: "new-instructor@example.com")
      imported_membership = imported_course.course_user_data.find_by!(user: imported_user)
      imported_assessment = imported_course.assessments.find_by!(name: "lab")
      imported_submission = Submission.find_by!(
        assessment: imported_assessment,
        course_user_datum: imported_membership,
        version: 1
      )
      imported_problem = imported_assessment.problems.find_by!(name: "code")
      imported_aud = AssessmentUserDatum.find_by!(
        assessment: imported_assessment,
        course_user_datum: imported_membership
      )

      expect(imported_course.name).to eq("imported-transfer-course")
      expect(imported_course.display_name).to eq("Transfer Course")
      expect(imported_course.course_user_data.find_by!(user: imported_instructor).instructor?)
        .to be(true)
      expect(imported_submission.notes).to eq("first")
      expect(imported_aud.latest_submission).to eq(imported_submission)
      expect(imported_aud.group.name).to eq("Team One")
      expect(
        Extension.find_by!(
          assessment: imported_assessment,
          course_user_datum: imported_membership
        ).days
      ).to eq(1)
      expect(Score.find_by!(submission: imported_submission,
                            problem: imported_problem).score).to eq(9.0)
      expect(Annotation.find_by!(submission: imported_submission,
                                 problem: imported_problem).comment).to eq("nice")
    end
  end

  it "rolls back when a non-reusable natural key already exists" do
    penalty = insert_record(
      ScoreAdjustment,
      type: "Penalty",
      kind: ScoreAdjustment::POINTS,
      value: 0.0
    )
    course = insert_record(
      Course,
      name: "collision-course",
      display_name: "Collision Course",
      semester: "f26",
      late_slack: 0,
      grace_days: 0,
      start_date: Date.new(2026, 8, 1),
      end_date: Date.new(2026, 12, 1),
      version_threshold: -1,
      late_penalty_id: penalty.id,
      version_penalty_id: penalty.id
    )

    Dir.mktmpdir("course-transfer-collision-") do |directory|
      context = CourseTransfer::Context.new(
        staging_path: directory,
        course:,
        version: CourseTransfer::Version::CURRENT,
        mode: :export,
        selected_parts: []
      )
      registry = CourseTransfer::CoreExporters.registry
      manager = CourseTransfer::ExportManager.new(registry:, context:)
      manager.export(manager.build_plan(CourseTransfer::ExportSelection.new(course:)))

      import_context = CourseTransfer::Context.new(
        staging_path: directory,
        course: nil,
        version: CourseTransfer::Version::CURRENT,
        mode: :import,
        selected_parts: []
      )

      course_count = Course.count
      expect do
        CourseTransfer::ImportManager.new(
          registry: CourseTransfer::CoreExporters.registry,
          context: import_context
        ).import
      end.to raise_error(CourseTransfer::InvalidCourseIdentifier)
      expect(Course.count).to eq(course_count)
    end
  end

  it "resolves more than one thousand submission keys without a deep OR expression" do
    course = insert_record(Course, name: "large-lookup-course")
    user = insert_record(User, email: "large-lookup@example.com")
    membership = insert_record(
      CourseUserDatum,
      course_id: course.id,
      user_id: user.id
    )
    assessment = insert_record(
      Assessment,
      course_id: course.id,
      name: "large-lookup-assessment"
    )
    versions = (1..1_001).to_a
    # Bulk setup keeps this regression focused on lookup query shape.
    # rubocop:disable Rails/SkipsModelValidations
    Submission.insert_all!(versions.map do |version|
      {
        assessment_id: assessment.id,
        course_user_datum_id: membership.id,
        version:
      }
    end)
    # rubocop:enable Rails/SkipsModelValidations
    insert_record(
      Submission,
      assessment_id: assessment.id,
      course_user_datum_id: membership.id,
      version: 2_000
    )

    prepared_row = Struct.new(:database_key, keyword_init: true)
    prepared = versions.map do |version|
      prepared_row.new(
        database_key: {
          assessment_id: assessment.id,
          course_user_datum_id: membership.id,
          version:
        }
      )
    end
    exporter = CourseTransfer::CoreExporters::SubmissionExporter.new
    manager = CourseTransfer::ImportManager.new(
      registry: CourseTransfer::CoreExporters.registry,
      context: nil
    )

    resolved = manager.send(:find_database_ids, exporter, prepared)

    expect(resolved.size).to eq(1_001)
    expect(resolved.values).to match_array(
      Submission.where(version: versions).pluck(:id)
    )
  end
end
