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

      Dir.mktmpdir("course-package-target-") do |target|
        tar_path = Pathname.new(target).join("package.tar")
        expect(described_class.pack(source_path, tar_path)).to eq(tar_path)

        Dir.mktmpdir("course-package-extract-") do |extracted|
          described_class.extract(tar_path, extracted)

          expect(Pathname.new(extracted).join("manifest.yml").read).to eq("manifest")
          expect(Pathname.new(extracted).join("nested", "records.yml").read).to eq("records")
        end
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

  it "rejects duplicate entries after path normalization" do
    Dir.mktmpdir("course-package-duplicate-") do |directory|
      tar_path = Pathname.new(directory).join("duplicate.tar")
      File.open(tar_path, "wb") do |file|
        Gem::Package::TarWriter.new(file) do |tar|
          tar.add_file("records.yml", 0o644) { |entry| entry.write("one") }
          tar.add_file("./records.yml", 0o644) { |entry| entry.write("two") }
        end
      end

      expect { described_class.extract(tar_path, Pathname.new(directory).join("target")) }
        .to raise_error(CourseTransfer::Package::UnsafeEntry, /duplicate/)
    end
  end

  it "rejects symlink entries and symlink destination components" do
    Dir.mktmpdir("course-package-symlink-") do |directory|
      tar_path = Pathname.new(directory).join("symlink.tar")
      File.open(tar_path, "wb") do |file|
        Gem::Package::TarWriter.new(file) do |tar|
          tar.add_symlink("records.yml", "outside", 0o777)
        end
      end
      expect { described_class.extract(tar_path, Pathname.new(directory).join("target")) }
        .to raise_error(CourseTransfer::Package::UnsafeEntry)

      target = Pathname.new(directory).join("target")
      FileUtils.mkdir_p(target)
      target.join("nested").make_symlink("/tmp")
      regular_tar = Pathname.new(directory).join("regular.tar")
      File.open(regular_tar, "wb") do |file|
        Gem::Package::TarWriter.new(file) do |tar|
          tar.add_file("nested/records.yml", 0o644) { |entry| entry.write("unsafe") }
        end
      end
      expect { described_class.extract(regular_tar, target) }
        .to raise_error(CourseTransfer::Package::UnsafeEntry)
    end
  end

  it "enforces configurable archive limits" do
    Dir.mktmpdir("course-package-limits-") do |directory|
      tar_path = Pathname.new(directory).join("limited.tar")
      File.open(tar_path, "wb") do |file|
        Gem::Package::TarWriter.new(file) do |tar|
          tar.add_file("records.yml", 0o644) { |entry| entry.write("records") }
        end
      end

      expect {
        described_class.extract(
          tar_path,
          Pathname.new(directory).join("target"),
          limits: { max_entries: 0 }
        )
      }.to raise_error(CourseTransfer::Package::UnsafeEntry, /too many entries/)
    end
  end
end
