require "rails_helper"
require "tmpdir"
require Rails.root.join("app/services/course_transfer/export")
require Rails.root.join("app/services/course_transfer/import")

RSpec.describe "normalized course transfer" do
  # These records exercise transfer SQL, not model lifecycle callbacks.
  # rubocop:disable Rails/SkipsModelValidations
  def insert_factory_record(model, factory, overrides = {})
    attributes = attributes_for(factory, **overrides)
                 .slice(*model.column_names.map(&:to_sym))
    model.insert_all!([attributes])
    model.find_by!(attributes)
  end
  # rubocop:enable Rails/SkipsModelValidations

  it "round-trips selected course, user, assessment, submission, and grading rows" do
    late_penalty = insert_factory_record(
      ScoreAdjustment, :penalty,
      type: "Penalty",
      kind: ScoreAdjustment::POINTS,
      value: 1.5
    )
    version_penalty = insert_factory_record(
      ScoreAdjustment, :penalty,
      type: "Penalty",
      kind: ScoreAdjustment::PERCENT,
      value: 2.0
    )
    course = insert_factory_record(
      Course, :course,
      name: "transfer-course",
      display_name: "Transfer Course",
      semester: "f26",
      grace_days: 2,
      late_penalty_id: late_penalty.id,
      version_penalty_id: version_penalty.id
    )
    user = insert_factory_record(
      User, :user,
      email: "transfer@example.com",
      first_name: "Transfer",
      last_name: "Student"
    )
    membership = insert_factory_record(
      CourseUserDatum, :student,
      course_id: course.id,
      user_id: user.id,
      lecture: "A",
      section: "1",
      dropped: false
    )
    excluded_user = insert_factory_record(
      User, :user,
      email: "excluded@example.com",
      first_name: "Excluded",
      last_name: "Student"
    )
    excluded_membership = insert_factory_record(
      CourseUserDatum, :student,
      course_id: course.id,
      user_id: excluded_user.id,
      dropped: false
    )
    assessment = insert_factory_record(
      Assessment, :assessment,
      course_id: course.id,
      name: "lab",
      display_name: "Lab",
      category_name: "Labs",
      max_grace_days: 2,
      handin_filename: "handin.tar",
      allow_student_assign_group: true,
      is_positive_grading: false,
      disable_network: false
    )
    excluded_assessment = insert_factory_record(
      Assessment, :assessment,
      course_id: course.id,
      name: "private-lab",
      display_name: "Private Lab",
      category_name: "Labs",
      handin_filename: "handin.tar",
      disable_handins: true
    )
    problem = insert_factory_record(
      Problem, :problem,
      assessment_id: assessment.id,
      name: "code",
      description: "Code quality",
      max_score: 10.0
    )
    submission = insert_factory_record(
      Submission, :submission,
      assessment_id: assessment.id,
      course_user_datum_id: membership.id,
      submitted_by_id: membership.id,
      version: 1,
      filename: "handin.tar",
      notes: "first",
      mime_type: "application/x-tar"
    )
    group = insert_factory_record(
      Group, :group,
      name: "Team One",
      created_at: Time.zone.parse("2026-08-10 11:00:00"),
      updated_at: Time.zone.parse("2026-08-10 11:00:00")
    )
    assessment_user_datum = insert_factory_record(
      AssessmentUserDatum, :assessment_user_datum,
      assessment_id: assessment.id,
      course_user_datum_id: membership.id,
      latest_submission_id: submission.id,
      group_id: group.id,
      grade_type: AssessmentUserDatum::NORMAL,
      membership_status: AssessmentUserDatum::CONFIRMED,
      version_number: 1
    )
    extension = insert_factory_record(
      Extension, :extension,
      assessment_id: assessment.id,
      course_user_datum_id: membership.id,
      days: 1
    )
    score = insert_factory_record(
      Score, :score,
      submission_id: submission.id,
      problem_id: problem.id,
      grader_id: 0,
      score: 9.0,
      feedback: "good",
      released: true
    )
    annotation = insert_factory_record(
      Annotation, :annotation,
      submission_id: submission.id,
      problem_id: problem.id,
      filename: "main.c",
      position: 1,
      line: 4,
      comment: "nice",
      value: 0.5,
      coordinate: "1,4",
      submitted_by: user.email,
      created_at: Time.zone.parse("2026-08-20 10:00:00")
    )
    attachment = insert_factory_record(
      Attachment, :attachment,
      course_id: course.id,
      assessment_id: assessment.id,
      filename: "reference.txt",
      mime_type: "text/plain",
      name: "Reference",
      category_name: "General",
      release_at: Time.zone.parse("2026-08-10 12:00:00")
    )
    attachment_blob = ActiveStorage::Blob.create_and_upload!(
      io: StringIO.new("attachment contents\n"),
      filename: attachment.filename,
      content_type: attachment.mime_type
    )
    attachment.attachment_file.attach(attachment_blob)

    source_tree = course.directory_path
    destination_tree = Rails.root.join("courses/imported-transfer-course")
    generated_configs = lambda do
      [Rails.root.join("courseConfig/importedtransfercourse.rb"),
       Rails.root.join("courseConfig/importedtransfercourse.rb.bak"),
       *Rails.root.glob("assessmentConfig/imported-transfer-course-lab-*.rb*")]
    end
    begin
      FileUtils.rm_rf(destination_tree)
      FileUtils.rm_f(generated_configs.call)
      FileUtils.mkdir_p([
                          source_tree.join("lab", "handin", user.email),
                          source_tree.join("lab", "handin", excluded_user.email),
                          source_tree.join("private-lab")
                        ])
      source_tree.join("course.rb").write("module CourseSource\nend\n")
      source_tree.join("random-course-file.txt").write("course extra\n")
      source_tree.join("lab", "assessment.rb").write("module AssessmentSource\nend\n")
      source_tree.join("lab", "handout.txt").write("handout\n")
      source_tree.join("lab", "random-assessment-file.txt").write("assessment extra\n")
      source_tree.join("lab", "handin", user.email, "handin.tar").write("handin\n")
      source_tree.join("lab", "handin", user.email, "random.txt").write("user extra\n")
      source_tree.join("lab", "handin", excluded_user.email, "private.txt")
                 .write("excluded\n")
      source_tree.join("lab", "handin", "#{excluded_user.email}_legacy.tar")
                 .write("excluded legacy\n")
      source_tree.join("lab", "handin", user.email, "annotated_handin.tar")
                 .write("annotated\n")
      source_tree.join("lab", "handin", user.email, "1_autograde.txt")
                 .write("feedback\n")
      source_tree.join("private-lab", "private.txt").write("private assessment\n")

      Dir.mktmpdir("course-transfer-spec-") do |directory|
        export_context = CourseTransfer::Context.new(staging_path: directory)
        export_manager = CourseTransfer::ExportManager.new(context: export_context)
        selection = CourseTransfer::ExportSelection.new(
          course:,
          users: User.where(id: user.id),
          assessments: Assessment.where(id: assessment.id)
        )

        relations = export_manager.build_relations(selection)
        export_manager.export(relations)

        exported_tree = Pathname.new(directory).join("files", "course")
        expect(Pathname.new(directory).join("files.jsonl")).not_to exist
        expect(Pathname.new(directory).join("files", course.name)).not_to exist
        expect(exported_tree.join("random-course-file.txt")).to exist
        expect(exported_tree.join("lab", "random-assessment-file.txt")).to exist
        expect(exported_tree.join("lab", "handin", user.email, "random.txt")).to exist
        expect(exported_tree.join("lab", "handin", excluded_user.email)).not_to exist
        expect(exported_tree.join("lab", "handin", "#{excluded_user.email}_legacy.tar"))
          .not_to exist
        expect(exported_tree.join("private-lab")).not_to exist
        expect(Pathname.new(directory).join("files", "attachments").glob("**/reference.txt").one?)
          .to be(true)

        adjustment_jsonl = Pathname.new(directory).join("score_adjustments.jsonl").read
        exported_adjustments = adjustment_jsonl.lines.map { |line| JSON.parse(line) }
        expect(exported_adjustments.size).to eq(2)
        expect(exported_adjustments.pluck("_id")).to eq([1, 2])
        expect(adjustment_jsonl.lines.size).to eq(2)

        submissions_path = Pathname.new(directory).join("submissions.jsonl")
        exported_submissions = submissions_path.each_line.map do |line|
          JSON.parse(line)
        end
        expect(exported_submissions.size).to eq(1)
        exported_submission = exported_submissions.first
        expect(exported_submission.fetch("assessment_id")).to include(
          "table" => "assessments",
          "id" => 1
        )

        Annotation.where(id: annotation.id).delete_all
        Score.where(id: score.id).delete_all
        Extension.where(id: extension.id).delete_all
        AssessmentUserDatum.where(id: assessment_user_datum.id).delete_all
        Submission.where(id: submission.id).delete_all
        Problem.where(id: problem.id).delete_all
        Group.where(id: group.id).delete_all
        attachment.attachment_file.purge
        Attachment.where(id: attachment.id).delete_all
        CourseUserDatum.where(id: membership.id).delete_all
        CourseUserDatum.where(id: excluded_membership.id).delete_all
        Assessment.where(id: assessment.id).delete_all
        Assessment.where(id: excluded_assessment.id).delete_all
        Course.where(id: course.id).delete_all
        User.where(id: user.id).delete_all
        User.where(id: excluded_user.id).delete_all

        import_context = CourseTransfer::Context.new(
          staging_path: directory,
          course_identifier: "imported-transfer-course",
          instructor_email: "new-instructor@example.com"
        )
        imported_course = CourseTransfer::ImportManager.new(
          context: import_context,
          user_ids: [1],
          assessment_ids: [1]
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
        expect(imported_course.cgdub_dependencies_updated_at).to be_present
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
        expect(imported_course.directory_path.join("course.rb").read)
          .to eq("module CourseSource\nend\n")
        expect(imported_assessment.folder_path.join("assessment.rb").read)
          .to eq("module AssessmentSource\nend\n")
        expect(imported_assessment.folder_path.join("handout.txt").read).to eq("handout\n")
        expect(imported_course.directory_path.join("random-course-file.txt").read)
          .to eq("course extra\n")
        expect(imported_assessment.folder_path.join("random-assessment-file.txt").read)
          .to eq("assessment extra\n")
        random_user_file = imported_assessment.handin_directory_path
                                              .join(imported_user.email, "random.txt")
        expect(random_user_file.read)
          .to eq("user extra\n")
        expect(imported_assessment.handin_directory_path.join(excluded_user.email)).not_to exist
        expect(imported_course.directory_path.join("private-lab")).not_to exist
        expect(Pathname.new(imported_submission.handin_file_path)).to be_file
        expect(Pathname.new(imported_submission.handin_file_path).read).to eq("handin\n")
        expect(Pathname.new(imported_submission.handin_annotated_file_path).read)
          .to eq("annotated\n")
        expect(Pathname.new(imported_submission.autograde_feedback_path).read)
          .to eq("feedback\n")
        expect(
          Attachment.find_by!(assessment: imported_assessment, name: "Reference")
                    .attachment_file.download
        ).to eq("attachment contents\n")
      end
    ensure
      FileUtils.rm_rf(source_tree)
      FileUtils.rm_rf(destination_tree)
      FileUtils.rm_f(generated_configs.call)
    end
  end

  it "rolls back when the destination course identifier already exists" do
    penalty = insert_factory_record(
      ScoreAdjustment, :penalty,
      type: "Penalty",
      kind: ScoreAdjustment::POINTS,
      value: 0.0
    )
    course = insert_factory_record(
      Course, :course,
      name: "collision-course",
      display_name: "Collision Course",
      grace_days: 0,
      late_penalty_id: penalty.id,
      version_penalty_id: penalty.id
    )

    Dir.mktmpdir("course-transfer-collision-") do |directory|
      context = CourseTransfer::Context.new(staging_path: directory)
      manager = CourseTransfer::ExportManager.new(context:)
      manager.export(manager.build_relations(CourseTransfer::ExportSelection.new(course:)))

      import_context = CourseTransfer::Context.new(staging_path: directory)

      course_count = Course.count
      expect do
        CourseTransfer::ImportManager.new(context: import_context).import
      end.to raise_error(CourseTransfer::InvalidCourseIdentifier)
      expect(Course.count).to eq(course_count)
    end
  end
end
