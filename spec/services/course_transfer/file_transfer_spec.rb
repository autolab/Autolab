require "rails_helper"
require "tmpdir"
require Rails.root.join("app/services/course_transfer/core_exporters")

module CourseTransferFileTransferSpec
  Record = Struct.new(:id, :path, :root, :base)

  class FakeModel
    class << self
      attr_accessor :records
    end

    def self.where(id:)
      records.select { |record| id.include?(record.id) }
    end
  end

  class FakeExporter < CourseTransfer::Exporter
    def initialize(record)
      @record = record
      super(name: :fake_files, model_class: FakeModel)
    end

    def file_mappings(relation)
      return [] unless relation.include?(@record)

      root = @record.root || @record.path.dirname
      [CourseTransfer::FileMapping.file(
        @record,
        "content",
        @record.path,
        root:,
        within: @record.base || root.dirname
      )]
    end
  end
end

RSpec.describe CourseTransfer::FileTransfer do
  after { CourseTransferFileTransferSpec::FakeModel.records = [] }

  def context_for(path, mode)
    CourseTransfer::Context.new(
      staging_path: path,
      course: nil,
      version: CourseTransfer::Version::CURRENT,
      mode:,
      selected_parts: []
    )
  end

  def export_fixture(root)
    source = root.join("source.txt")
    source.write("portable file\n")
    record = CourseTransferFileTransferSpec::Record.new(42, source)
    CourseTransferFileTransferSpec::FakeModel.records = [record]
    registry = CourseTransfer::ExportRegistry.new.register(
      CourseTransferFileTransferSpec::FakeExporter.new(record)
    )
    key = { "identifier" => "fake" }
    described_class.export(
      CourseTransfer::ExportPlan.new(fake_files: [record]),
      registry,
      context: context_for(root, :export),
      key_maps: { fake_files: { record.id => key } }
    )
    [record, registry, key, YAML.load_stream(root.join("files.yml").read)]
  end

  it "exports a manifest and restores mapped files" do
    Dir.mktmpdir("course-transfer-files-") do |directory|
      root = Pathname.new(directory)
      destination = root.join("restored", "file.txt")
      record, registry, key, manifest = export_fixture(root)
      expect(manifest).to contain_exactly(
        hash_including(
          "table" => "fake_files",
          "key" => key,
          "name" => "content",
          "sha256" => Digest::SHA256.hexdigest("portable file\n")
        )
      )
      expect(root.join(manifest.first.fetch("payload"))).to exist

      record.path = destination

      described_class.import(
        registry,
        context: context_for(root, :import),
        imported_ids: { fake_files: [record.id] },
        key_maps: { fake_files: { JSON.generate(key) => record.id } }
      )

      expect(destination.read).to eq("portable file\n")
      expect(destination).to exist
    end
  end

  it "rejects changed payloads and destinations outside the declared root" do
    Dir.mktmpdir("course-transfer-files-") do |directory|
      root = Pathname.new(directory)
      record, registry, key, manifest = export_fixture(root)
      payload = root.join(manifest.first.fetch("payload"))
      payload.write("changed")
      record.path = root.join("restored", "file.txt")

      expect do
        described_class.import(
          registry,
          context: context_for(root, :import),
          imported_ids: { fake_files: [record.id] },
          key_maps: { fake_files: { JSON.generate(key) => record.id } }
        )
      end.to raise_error(CourseTransfer::FileTransferError, /checksum/)

      payload.write("portable file\n")
      record.path = root.join("outside.txt")
      record.root = root.join("restored")
      record.base = root
      expect do
        described_class.import(
          registry,
          context: context_for(root, :import),
          imported_ids: { fake_files: [record.id] },
          key_maps: { fake_files: { JSON.generate(key) => record.id } }
        )
      end.to raise_error(CourseTransfer::FileTransferError, /escapes its owner/)
    end
  end
end
