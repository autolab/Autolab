require "rails_helper"
require Rails.root.join("app/services/course_transfer/version")

RSpec.describe CourseTransfer::Version do
  let(:manifest) do
    {
      "format" => described_class::FORMAT_ID,
      "version" => described_class::CURRENT,
      "parts" => []
    }
  end

  it "reads and validates manifests" do
    Dir.mktmpdir("course-version-") do |directory|
      root = Pathname.new(directory)
      root.join(described_class::MANIFEST_FILENAME).write(manifest.to_yaml)
      expect(described_class.read_manifest(root)).to eq(manifest)

      root.join(described_class::MANIFEST_FILENAME).write(manifest.except("parts").to_yaml)
      expect { described_class.read_manifest(root) }
        .to raise_error(described_class::InvalidManifest, /parts/)
    end
  end

  it "accepts version 1 packages and rejects unknown versions" do
    expect(described_class.assert_importable!(1)).to be(true)
    expect { described_class.assert_importable!(described_class::CURRENT + 1) }
      .to raise_error(described_class::Unsupported)
  end
end
