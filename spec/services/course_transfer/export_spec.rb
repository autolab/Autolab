require "rails_helper"
require "tmpdir"
require Rails.root.join("app/services/course_transfer/export")
require Rails.root.join("app/services/course_transfer/import")

RSpec.describe CourseTransfer::ExportManager do
  it "uses incremental package IDs and preserves null foreign keys" do
    table = CourseTransfer::Schema.fetch(:attachments)
    manager = described_class.new(context: nil)
    row = table.fields.index_with { nil }.transform_keys(&:to_s).merge(
      "id" => 7,
      "course_id" => 11,
      "name" => "Syllabus",
      "filename" => "syllabus.pdf"
    )
    course_package_id = 1

    document = manager.send(
      :serialize_row,
      table,
      row,
      1,
      { courses: { 11 => course_package_id }, assessments: {} }
    )

    expect(document.fetch("_id")).to eq(1)
    expect(document.fetch("course_id")).to eq("table" => "courses", "id" => 1)
    expect(document.fetch("assessment_id")).to be_nil
  end

  it "uses a safe sentinel when an optional referenced row was not selected" do
    table = CourseTransfer::Schema.fetch(:scores)
    manager = described_class.new(context: nil)
    row = table.fields.index_with { nil }.transform_keys(&:to_s).merge(
      "id" => 9,
      "submission_id" => 4,
      "problem_id" => 5,
      "grader_id" => 99
    )

    document = manager.send(
      :serialize_row,
      table,
      row,
      1,
      { submissions: { 4 => 1 }, problems: { 5 => 1 }, course_user_data: {} }
    )

    expect(document.fetch("grader_id")).to eq(0)
  end
end

RSpec.describe CourseTransfer::ExportSelection do
  # Selection only needs persisted rows; callbacks would add unrelated course
  # and assessment records to this query-level contract spec.
  # rubocop:disable Rails/SkipsModelValidations
  def insert_record(model, attributes)
    model.insert_all!([attributes])
    model.find_by!(attributes)
  end
  # rubocop:enable Rails/SkipsModelValidations

  it "always includes the course and intersects selected users with selected assessments" do
    course = insert_record(Course, name: "selected-course")
    other_course = insert_record(Course, name: "other-course")
    selected_user = insert_record(User, email: "selected@example.com")
    excluded_user = insert_record(User, email: "excluded@example.com")
    outsider = insert_record(User, email: "outsider@example.com")
    selected_assessment = insert_record(Assessment, course_id: course.id, name: "selected")
    excluded_assessment = insert_record(Assessment, course_id: course.id, name: "excluded")
    outside_assessment = insert_record(Assessment, course_id: other_course.id, name: "outside")
    course_image = insert_record(
      ContainerImage,
      course_id: course.id,
      name: "course-image",
      status: ContainerImage.statuses.fetch("ready"),
      image_uri: "example.com/course-image:latest",
      dockerfile_contents: "FROM ruby:3.2\n",
      created_at: Time.current,
      updated_at: Time.current
    )
    insert_record(
      ContainerImage,
      course_id: other_course.id,
      name: "other-course-image",
      status: ContainerImage.statuses.fetch("ready"),
      image_uri: "example.com/other-course-image:latest",
      dockerfile_contents: "FROM ruby:3.2\n",
      created_at: Time.current,
      updated_at: Time.current
    )
    selected_membership = insert_record(
      CourseUserDatum,
      course_id: course.id,
      user_id: selected_user.id
    )
    excluded_membership = insert_record(
      CourseUserDatum,
      course_id: course.id,
      user_id: excluded_user.id
    )
    outside_membership = insert_record(
      CourseUserDatum,
      course_id: other_course.id,
      user_id: outsider.id
    )
    included_submission = insert_record(
      Submission,
      assessment_id: selected_assessment.id,
      course_user_datum_id: selected_membership.id,
      submitted_by_id: outside_membership.id,
      version: 1
    )
    insert_record(
      Score,
      submission_id: included_submission.id,
      grader_id: outside_membership.id,
      score: 10
    )
    insert_record(
      Submission,
      assessment_id: selected_assessment.id,
      course_user_datum_id: excluded_membership.id,
      version: 2
    )
    insert_record(
      Submission,
      assessment_id: excluded_assessment.id,
      course_user_datum_id: selected_membership.id,
      version: 3
    )
    insert_record(
      Submission,
      assessment_id: outside_assessment.id,
      course_user_datum_id: outside_membership.id,
      version: 4
    )

    selection = described_class.new(
      course:,
      users: User.where(id: [selected_user.id, outsider.id]),
      assessments: Assessment.where(id: [selected_assessment.id, outside_assessment.id])
    )
    seeds = selection.seed_relations

    expect(seeds.fetch(:courses)).to contain_exactly(course)
    expect(seeds.fetch(:users)).to contain_exactly(selected_user)
    expect(seeds.fetch(:course_user_data)).to contain_exactly(selected_membership)
    expect(seeds.fetch(:assessments)).to contain_exactly(selected_assessment)
    expect(seeds.fetch(:submissions)).to contain_exactly(included_submission)

    relations = CourseTransfer::ExportManager.new(context: nil).build_relations(selection)
    expect(relations.fetch(:submissions)).to contain_exactly(included_submission)
    expect(relations.fetch(:users)).to contain_exactly(selected_user)
    expect(relations.fetch(:course_user_data)).to contain_exactly(selected_membership)
    expect(relations.fetch(:container_images)).to contain_exactly(course_image)
  end

  it "can export a course without users, assessments, or submissions" do
    course = insert_record(Course, name: "empty-course")
    selection = described_class.new(course:)
    seeds = selection.seed_relations

    expect(seeds.fetch(:courses)).to contain_exactly(course)
    expect(seeds.fetch(:users)).to be_empty
    expect(seeds.fetch(:course_user_data)).to be_empty
    expect(seeds.fetch(:assessments)).to be_empty
    expect(seeds.fetch(:submissions)).to be_empty

    Dir.mktmpdir("course-transfer-empty-") do |directory|
      context = CourseTransfer::Context.new(staging_path: directory)
      manager = CourseTransfer::ExportManager.new(context:)
      manager.export(manager.build_relations(selection))

      courses_yaml = Pathname.new(directory).join("courses.yml").read
      expect(courses_yaml).to start_with("---\n_id: 1\n")
      expect(courses_yaml).not_to include("records:")
      expect(YAML.load_stream(courses_yaml).size).to eq(1)
      expect(Pathname.new(directory).join("users.yml").read).to be_empty
      preview = JSON.parse(Pathname.new(directory).join("preview.json").read)
      expect(preview).to eq(
        "version" => CourseTransfer::Version::CURRENT,
        "users" => [],
        "assessments" => []
      )
    end
  end
end
