require "rails_helper"
require "tmpdir"
require Rails.root.join("app/services/course_transfer/package")

RSpec.describe CourseTransfer::Package do
  it "packs and extracts package files" do
    Dir.mktmpdir("course-package-source-") do |source|
      source_path = Pathname.new(source)
      source_path.join("manifest.yml").write("manifest")
      FileUtils.mkdir_p(source_path.join("nested"))
      source_path.join("nested", "records.yml").write("records")

      tar_path = source_path.join("package.tar")
      tar_path.binwrite(described_class.pack(source_path))

      Dir.mktmpdir("course-package-target-") do |target|
        described_class.extract(tar_path, target)

        expect(Pathname.new(target).join("manifest.yml").read).to eq("manifest")
        expect(Pathname.new(target).join("nested", "records.yml").read).to eq("records")
      end
    end
  end

  it "rejects path traversal entries" do
    Dir.mktmpdir("course-package-unsafe-") do |directory|
      tar_path = Pathname.new(directory).join("unsafe.tar")
      File.open(tar_path, "wb") do |file|
        Gem::Package::TarWriter.new(file) do |tar|
          tar.add_file("../outside", 0o644) { |entry| entry.write("unsafe") }
        end
      end

      expect { described_class.extract(tar_path, Pathname.new(directory).join("target")) }
        .to raise_error(CourseTransfer::Package::UnsafeEntry)
    end
  end
end
