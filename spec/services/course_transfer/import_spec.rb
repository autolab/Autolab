require "rails_helper"
require Rails.root.join("app/services/course_transfer/core_exporters")
require Rails.root.join("app/services/course_transfer/import")

RSpec.describe CourseTransfer::ImportOrder do
  it "orders the core graph so every foreign-key target is inserted first" do
    registry = CourseTransfer::CoreExporters.registry
    order = described_class.new(registry).call.map(&:name)

    registry.each do |exporter|
      exporter.import_dependencies.each do |dependency|
        expect(order.index(dependency)).to be < order.index(exporter.name)
      end
    end

    expect(order.index(:submissions)).to be < order.index(:assessment_user_data)
  end

  it "reports non-deferred cycles" do
    left = Class.new(CourseTransfer::Exporter) do
      def ref_fields
        { right_id: :right }
      end
    end.new(name: :left, model_class: User)

    right = Class.new(CourseTransfer::Exporter) do
      def ref_fields
        { left_id: :left }
      end
    end.new(name: :right, model_class: User)

    registry = CourseTransfer::ExportRegistry.new.register(left).register(right)

    expect { described_class.new(registry).call }
      .to raise_error(CourseTransfer::CyclicImportDependencies, /left -> right -> left/)
  end

  it "orders references before dependents regardless of registration order" do
    parent = CourseTransfer::Exporter.new(name: :parents, model_class: User)
    child = Class.new(CourseTransfer::Exporter) do
      def ref_fields
        { parent_id: :parents }
      end
    end.new(name: :children, model_class: User)

    registry = CourseTransfer::ExportRegistry.new.register(child).register(parent)

    expect(described_class.new(registry).call.map(&:name)).to eq(%i[parents children])
  end
end
