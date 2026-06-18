require "rails_helper"
require Rails.root.join("app/services/course_transfer/version")

RSpec.describe CourseTransfer::Version do
  let(:manifest) do
    {
      "format" => described_class::FORMAT_ID,
      "version" => described_class::CURRENT,
      "min_target_version" => described_class::MIN_SUPPORTED_TARGET.to_s,
      "parts" => []
    }
  end

  it "uses the same manifest validation for tar detection and extracted packages" do
    Dir.mktmpdir("course-version-") do |directory|
      root = Pathname.new(directory)
      manifest_path = root.join(described_class::MANIFEST_FILENAME)
      manifest_path.write(manifest.to_yaml)
      expect(described_class.detect(root)).to eq(described_class::CURRENT)
      expect(described_class.read_manifest(root)).to eq(manifest)

      tar_path = root.join("package.tar")
      File.open(tar_path, "wb") do |file|
        Gem::Package::TarWriter.new(file) do |tar|
          tar.add_file(described_class::MANIFEST_FILENAME, 0o644) do |entry|
            entry.write(manifest.to_yaml)
          end
        end
      end
      expect(described_class.detect_from_tar_file(tar_path)).to eq(described_class::CURRENT)
    end
  end

  it "rejects incomplete manifests consistently" do
    Dir.mktmpdir("course-version-invalid-") do |directory|
      root = Pathname.new(directory)
      invalid = manifest.except("min_target_version")
      root.join(described_class::MANIFEST_FILENAME).write(invalid.to_yaml)

      expect { described_class.detect(root) }
        .to raise_error(described_class::InvalidManifest, /min_target_version/)
      expect { described_class.read_manifest(root) }
        .to raise_error(described_class::InvalidManifest, /min_target_version/)
    end
  end
end
