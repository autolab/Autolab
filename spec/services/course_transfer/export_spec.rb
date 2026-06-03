# frozen_string_literal: true

require "rails_helper"
require "tmpdir"

RSpec.describe CourseTransfer::Export do
  let(:context) { CourseTransfer::Context.new(staging_path: Pathname.new(Dir.mktmpdir), course: nil,
                                               version: "1.0.0", mode: :export, selected_parts: []) }

  after do
    FileUtils.rm_rf(context.staging_path)
  end

  it "walks dependencies depth-first and memoizes the returned values" do
    events = []
    shared = Class.new(CourseTransfer::Export::Exporter) do
      define_method(:initialize) do |memo_key:|
        super()
        @memo_key = memo_key
      end
      define_method(:memo_key) { |_context: nil| @memo_key }
      define_method(:pre_export_hook) { |_context: nil| events << :shared_pre }
      define_method(:post_export_hook) do |_dependencies, _context: nil|
        events << :shared_post
        "shared"
      end
    end.new(memo_key: :shared)

    root = Class.new(CourseTransfer::Export::Exporter) do
      define_method(:initialize) do |memo_key:|
        super()
        @memo_key = memo_key
      end
      define_method(:memo_key) { |_context: nil| @memo_key }
      define_method(:dependencies) do |_context: nil|
        { "shared" => shared }
      end
      define_method(:pre_export_hook) { |_context: nil| events << :root_pre }
      define_method(:post_export_hook) do |dependencies, _context: nil|
        events << :root_post
        { "root" => dependencies.fetch("shared") }
      end
    end.new(memo_key: :root)

    runner = CourseTransfer::Export::Runner.new(context: context)
    first = runner.export(root)
    second = runner.export(root)

    expect(second).to equal(first)
    expect(first).to eq("root" => "shared")
    expect(events).to eq(%i[root_pre shared_pre shared_post root_post])
  end

  it "exports simple values through an inline exporter" do
    exporter = CourseTransfer::Export::InlineValueExporter.new("a string", memo_key: :title)

    expect(CourseTransfer::Export.export(exporter, context: context)).to eq("a string")
  end

  it "does not memoize exporters whose memo key is nil" do
    calls = 0
    exporter = Class.new(CourseTransfer::Export::InlineValueExporter) do
      define_method(:post_export_hook) do |_dependencies, _context: nil|
        calls += 1
        super(_dependencies, _context: _context)
      end
    end.new("a string")
    runner = CourseTransfer::Export::Runner.new(context: context)

    runner.export(exporter)
    runner.export(exporter)

    expect(calls).to eq(2)
    expect(runner.memo).to be_empty
  end

  it "passes dependency results to the inline dependency exporter as a hash" do
    exporter = Class.new(CourseTransfer::Export::InlineDependencyExporter) do
      define_method(:dependencies) do |_context: nil|
        {
          "title" => CourseTransfer::Export::InlineValueExporter.new("course", memo_key: :title)
        }
      end
    end.new(memo_key: :course)

    expect(CourseTransfer::Export.export(exporter, context: context)).to eq("title" => "course")
  end

  it "returns a natural key for a file-backed YAML value" do
    exporter = Class.new(CourseTransfer::Export::FileYamlExporter) do
      define_method(:dependencies) do |_context: nil|
        { "name" => CourseTransfer::Export::InlineValueExporter.new("assessment", memo_key: :name) }
      end
    end.new(
      filename: "assessments/assessment.yml", memo_key: :assessment
    )

    result = CourseTransfer::Export::Runner.new(context: context).export(exporter)

    expect(result).to eq("file" => "assessments/assessment.yml")
    expect(context.staging_path.join(result.fetch("file"))).to be_file
    expect(YAML.safe_load(context.staging_path.join(result.fetch("file")).read)["name"]).to eq("assessment")
  end

  it "copies a source file into staging and returns its natural key" do
    source_path = Pathname.new(Dir.mktmpdir).join("submission.txt")
    source_path.write("submission contents")
    exporter = CourseTransfer::Export::FileCopyExporter.new(
      source_path: source_path,
      filename: "submissions/submission.txt",
      memo_key: :submission
    )

    result = CourseTransfer::Export::Runner.new(context: context).export(exporter)

    expect(result).to eq("file" => "submissions/submission.txt")
    expect(context.staging_path.join(result.fetch("file")).read).to eq("submission contents")
  ensure
    FileUtils.rm_rf(source_path.dirname) if source_path
  end
end
