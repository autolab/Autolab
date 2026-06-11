require "rails_helper"
require "tmpdir"
require Rails.root.join("app/services/course_transfer/core_exporters")

module CourseTransferFileTransferSpec
  Record = Struct.new(:id)

  class FakeModel
    class << self
      attr_accessor :records
    end

    def self.where(id:)
      records.select { |record| id.include?(record.id) }
    end
  end

  class FakeExporter < CourseTransfer::Exporter
    def initialize(record, source:, destination:)
      @record = record
      @source = source
      @destination = destination
      super(name: :fake_files, model_class: FakeModel)
    end

    def file_mappings(relation, direction:)
      return [] unless relation.include?(@record)

      mapping = if direction == :export
                  CourseTransfer::FileMapping.new(
                    record: @record,
                    kind: "content",
                    source: @source,
                    relative_path: "nested/file.txt"
                  )
                else
                  CourseTransfer::FileMapping.new(
                    record: @record,
                    kind: "content",
                    destination: @destination
                  )
                end
      [mapping]
    end
  end
end

RSpec.describe CourseTransfer::FileTransfer do
  def context_for(path, mode)
    CourseTransfer::Context.new(
      staging_path: path,
      course: nil,
      version: CourseTransfer::Version::CURRENT,
      mode:,
      selected_parts: []
    )
  end

  it "exports a manifest and restores mapped files" do
    Dir.mktmpdir("course-transfer-files-") do |directory|
      root = Pathname.new(directory)
      source = root.join("source.txt")
      destination = root.join("restored", "file.txt")
      source.write("portable file\n")
      record = CourseTransferFileTransferSpec::Record.new(42)
      CourseTransferFileTransferSpec::FakeModel.records = [record]
      exporter = CourseTransferFileTransferSpec::FakeExporter.new(
        record,
        source:,
        destination:
      )
      registry = CourseTransfer::ExportRegistry.new.register(exporter)
      key = { "identifier" => "fake" }

      CourseTransfer::FileTransfer.export(
        CourseTransfer::ExportPlan.new(fake_files: [record]),
        registry,
        context: context_for(root, :export),
        key_maps: { fake_files: { record.id => key } }
      )

      manifest = YAML.load_stream(root.join("files.yml").read)
      expect(manifest).to contain_exactly(
        hash_including(
          "owner_table" => "fake_files",
          "owner_key" => key,
          "kind" => "content",
          "relative_path" => "nested/file.txt",
          "sha256" => Digest::SHA256.hexdigest("portable file\n")
        )
      )
      expect(root.join(manifest.first.fetch("payload_path"))).to exist

      CourseTransfer::FileTransfer.import(
        registry,
        context: context_for(root, :import),
        imported_ids: { fake_files: [record.id] },
        key_maps: { fake_files: { JSON.generate(key) => record.id } }
      )

      expect(destination.read).to eq("portable file\n")
      expect(destination).to exist
    end
  ensure
    CourseTransferFileTransferSpec::FakeModel.records = []
  end
end
