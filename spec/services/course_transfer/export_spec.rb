require "rails_helper"
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

  it "requires concrete row conversion implementations" do
    expect { exporter.serialize([]) }.to raise_error(NotImplementedError)
    expect { exporter.import_attributes({}) }.to raise_error(NotImplementedError)
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
