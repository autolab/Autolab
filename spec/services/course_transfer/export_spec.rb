require "rails_helper"
require "tmpdir"
require Rails.root.join("app/services/course_transfer/core_exporters")
require Rails.root.join("app/services/course_transfer/import")

RSpec.describe CourseTransfer::Exporter do
  subject(:exporter) do
    described_class.new(name: :widgets, model_class: User)
  end

  it "defaults one exporter to one YAML table file" do
    expect(exporter.name).to eq(:widgets)
    expect(exporter.filename).to eq("widgets.yml")
    expect(exporter.model_class).to eq(User)
  end

  it "leaves relations lazy and unchanged by default" do
    relation = User.where(administrator: false)

    expect(exporter.query(relation)).to equal(relation)
    expect(exporter.dependencies(relation)).to eq({})
  end

  it "maps plucked values to declared columns" do
    expect(exporter.row_from([12])).to eq("id" => 12)
  end
end

RSpec.describe CourseTransfer::ExportRegistry do
  subject(:registry) { described_class.new }

  let(:exporter) do
    CourseTransfer::Exporter.new(name: :users, model_class: User)
  end

  it "registers and fetches exporters by package name" do
    registry.register(exporter)

    expect(registry.fetch("users")).to equal(exporter)
    expect(registry.names).to eq([:users])
  end

  it "rejects duplicate package names" do
    registry.register(exporter)

    expect { registry.register(exporter) }
      .to raise_error(CourseTransfer::DuplicateExporter)
  end

  it "rejects unknown package names" do
    expect { registry.fetch(:missing) }
      .to raise_error(CourseTransfer::UnknownExporter)
  end
end

RSpec.describe CourseTransfer::ExportPlan do
  it "stores lazy relations by table-file name" do
    relation = User.where(administrator: false)
    plan = described_class.new(users: relation)

    expect(plan.names).to eq([:users])
    expect(plan.relation_for(:users)).to equal(relation)
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
      version: 1
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

    plan = CourseTransfer::ExportManager.new(
      registry: CourseTransfer::CoreExporters.registry,
      context: nil
    ).build_plan(selection)
    expect(plan.relation_for(:submissions)).to contain_exactly(included_submission)
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
      context = CourseTransfer::Context.new(
        staging_path: directory,
        course:,
        version: CourseTransfer::Version::CURRENT,
        mode: :export,
        selected_parts: []
      )
      manager = CourseTransfer::ExportManager.new(
        registry: CourseTransfer::CoreExporters.registry,
        context:
      )
      manager.export(manager.build_plan(selection))

      courses_yaml = Pathname.new(directory).join("courses.yml").read
      expect(courses_yaml).to start_with("---\n_key:\n")
      expect(courses_yaml).not_to include("records:")
      expect(YAML.load_stream(courses_yaml).size).to eq(1)
      expect(Pathname.new(directory).join("users.yml").read).to be_empty
    end
  end
end
