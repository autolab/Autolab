require "rails_helper"
require "tmpdir"
require Rails.root.join("app/services/course_transfer/core_exporters")

RSpec.describe CourseTransfer::FileTransfer do
  def transfer(root)
    context = CourseTransfer::Context.new(
      staging_path: root,
      version: CourseTransfer::Version::CURRENT
    )
    described_class.new(context:, key_maps: {})
  end

  it "addresses attachments by natural key while retaining their normal filename" do
    Dir.mktmpdir("course-transfer-files-") do |directory|
      root = Pathname.new(directory)
      key = { "name" => "Reference", "filename" => "reference.pdf" }
      path = transfer(root).send(:attachment_path, key, "reference.pdf")
      other = transfer(root).send(
        :attachment_path,
        key.merge("name" => "Another reference"),
        "reference.pdf"
      )

      expect(path.basename.to_s).to eq("reference.pdf")
      expect(path.dirname.basename.to_s)
        .to eq(Digest::SHA256.hexdigest(CourseTransfer::Serialization.canonical(key)))
      expect(path.to_s).to start_with(root.join("files", "attachments").to_s)
      expect(other.basename).to eq(path.basename)
      expect(other.dirname).not_to eq(path.dirname)
    end
  end

  it "copies arbitrary directory contents while pruning excluded subtrees" do
    Dir.mktmpdir("course-transfer-files-") do |directory|
      root = Pathname.new(directory)
      source = root.join("source")
      destination = root.join("destination")
      FileUtils.mkdir_p([source.join("included"), source.join("excluded")])
      source.join("included", "random.txt").write("included")
      source.join("excluded", "private.txt").write("excluded")

      transfer(root).send(:copy_tree, source, destination) do |path|
        path.to_s.start_with?(source.join("excluded").to_s)
      end

      expect(destination.join("included", "random.txt").read).to eq("included")
      expect(destination.join("excluded")).not_to exist
    end
  end

  it "copies course trees concurrently when an atomic move crosses filesystems" do
    Dir.mktmpdir("course-transfer-files-") do |directory|
      root = Pathname.new(directory)
      source = root.join("source")
      destination = root.join("destination")
      FileUtils.mkdir_p(source.join("empty"))
      source.join("first.txt").write("first")
      source.join("second.txt").write("second")
      allow(File).to receive(:rename).with(source, destination).and_raise(Errno::EXDEV)

      transfer(root).send(:move_tree, source, destination)

      expect(source).not_to exist
      expect(destination.join("first.txt").read).to eq("first")
      expect(destination.join("second.txt").read).to eq("second")
      expect(destination.join("empty")).to be_directory
    end
  end
end
