require "fileutils"
require "pathname"
require "rubygems/package"
require "stringio"

module CourseTransfer
  # Packs and safely extracts course-transfer tar archives.
  class Package
    # Raised when a tar contains traversal, link, or special entries.
    class UnsafeEntry < StandardError; end

    # Packs every regular file under +staging_path+ into a tar string.
    #
    # @param staging_path [String, Pathname]
    # @return [String] binary tar contents
    def self.pack(staging_path)
      root = Pathname.new(staging_path)
      stream = StringIO.new("".b)

      Gem::Package::TarWriter.new(stream) do |tar|
        root.glob("**/*").sort.each do |path|
          next unless path.file?

          relative_path = path.relative_path_from(root).to_s
          tar.add_file(relative_path, File.stat(path).mode) do |tar_file|
            tar_file.write(path.binread)
          end
        end
      end
      stream.string
    end

    # Safely extracts regular files from a tar archive.
    #
    # @param tar_path [String, Pathname]
    # @param destination [String, Pathname]
    # @return [Pathname] extraction root
    # @raise [CourseTransfer::Package::UnsafeEntry] for traversal or link entries
    def self.extract(tar_path, destination)
      root = Pathname.new(destination).expand_path
      FileUtils.mkdir_p(root)

      File.open(tar_path, "rb") do |io|
        Gem::Package::TarReader.new(io) do |tar|
          tar.each do |entry|
            relative = safe_relative_path(entry.full_name)
            target = root.join(relative).expand_path
            unless target.to_s == root.to_s || target.to_s.start_with?("#{root}#{File::SEPARATOR}")
              raise UnsafeEntry, "tar entry escapes package root: #{entry.full_name}"
            end

            if entry.directory?
              FileUtils.mkdir_p(target)
            elsif entry.file?
              FileUtils.mkdir_p(target.dirname)
              File.open(target, "wb") { |file| IO.copy_stream(entry, file) }
            else
              raise UnsafeEntry,
                    "tar links and special entries are not supported: #{entry.full_name}"
            end
          end
        end
      end
      root
    end

    # @param name [String]
    # @return [Pathname]
    def self.safe_relative_path(name)
      cleaned = name.to_s.delete_prefix("./")
      path = Pathname.new(cleaned).cleanpath
      if path.absolute? || path.to_s == ".." || path.each_filename.first == ".."
        raise UnsafeEntry, "unsafe tar entry: #{name}"
      end

      path
    end
    private_class_method :safe_relative_path
  end
end
