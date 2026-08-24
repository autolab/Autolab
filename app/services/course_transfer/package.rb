require "fileutils"
require "find"
require "pathname"
require "rubygems/package"
require_relative "errors"

module CourseTransfer
  # Packs and safely extracts course-transfer tar archives.
  class Package
    MAX_ENTRIES = Integer(ENV.fetch("AUTOLAB_COURSE_TRANSFER_MAX_ENTRIES", "10000"))
    MAX_ENTRY_BYTES = Integer(
      ENV.fetch("AUTOLAB_COURSE_TRANSFER_MAX_ENTRY_BYTES", "268435456")
    )
    MAX_BYTES = Integer(ENV.fetch("AUTOLAB_COURSE_TRANSFER_MAX_BYTES", "1073741824"))

    # Raised when a tar contains traversal, link, or special entries.
    class UnsafeEntry < Error; end

    # Packs the complete directory tree under +staging_path+ into +destination+.
    #
    # @param staging_path [String, Pathname]
    # @param destination [String, Pathname]
    # @return [Pathname] destination tar path
    def self.pack(staging_path, destination, limits: {})
      root = Pathname.new(staging_path)
      output = Pathname.new(destination)
      raise UnsafeEntry, "package root is not a directory" unless root.directory? && !root.symlink?
      raise UnsafeEntry, "package destination is a symbolic link" if output.symlink?

      limits = archive_limits.merge(limits.transform_keys(&:to_sym))
      entries = 0
      bytes = 0
      FileUtils.mkdir_p(output.dirname)
      File.open(output, "wb") do |stream|
        Gem::Package::TarWriter.new(stream) do |tar|
          Find.find(root.to_s) do |name|
            path = Pathname.new(name)
            next if path == root || path.expand_path == output.expand_path

            raise UnsafeEntry, "symbolic links are not supported: #{path}" if path.symlink?
            unless path.directory? || path.file?
              raise UnsafeEntry, "special files are not supported: #{path}"
            end

            entries += 1
            relative_path = path.relative_path_from(root).to_s
            if path.directory?
              enforce_limits!(entries, 0, bytes, limits)
              tar.mkdir(relative_path, path.lstat.mode & 0o7777)
              next
            end

            size = path.lstat.size
            bytes += size
            enforce_limits!(entries, size, bytes, limits)

            tar.add_file(relative_path, path.lstat.mode & 0o7777) do |tar_file|
              File.open(path, "rb") { |input| IO.copy_stream(input, tar_file) }
            end
          end
        end
      end
      output
    end

    # Safely extracts regular files from a tar archive.
    #
    # @param tar_path [String, Pathname]
    # @param destination [String, Pathname]
    # @return [Pathname] extraction root
    # @raise [CourseTransfer::Package::UnsafeEntry] for traversal or link entries
    def self.extract(tar_path, destination, limits: {})
      destination = Pathname.new(destination)
      raise UnsafeEntry, "package destination is a symbolic link" if destination.symlink?

      root = destination.expand_path
      FileUtils.mkdir_p(root)
      limits = archive_limits.merge(limits.transform_keys(&:to_sym))
      seen = {}
      required_directories = Set.new
      entries = 0
      bytes = 0

      File.open(tar_path, "rb") do |io|
        Gem::Package::TarReader.new(io) do |tar|
          tar.each do |entry|
            entries += 1
            enforce_limits!(entries, 0, bytes, limits)
            relative = safe_relative_path(entry.full_name)
            key = relative.to_s
            raise UnsafeEntry, "duplicate tar entry: #{entry.full_name}" if seen.key?(key)

            ancestors = relative.each_filename.to_a[0...-1]
                                .each_with_object([]) do |part, paths|
              paths << [paths.last, part].compact.join(File::SEPARATOR)
            end
            if ancestors.any? { |ancestor| seen[ancestor] == :file } ||
               (entry.file? && required_directories.include?(key))
              raise UnsafeEntry, "conflicting tar entries: #{entry.full_name}"
            end

            required_directories.merge(ancestors)
            seen[key] = entry.directory? ? :directory : :file
            target = root.join(relative).expand_path

            if entry.directory?
              ensure_safe_target!(root, relative)
              FileUtils.mkdir_p(target)
            elsif entry.file?
              size = entry.size.to_i
              raise UnsafeEntry, "tar entry has an invalid size" if size.negative?

              bytes += size
              enforce_limits!(entries, size, bytes, limits)
              ensure_safe_target!(root, relative)
              FileUtils.mkdir_p(target.dirname)
              File.open(target, File::WRONLY | File::CREAT | File::EXCL, 0o644) do |file|
                IO.copy_stream(entry, file)
              end
            else
              raise UnsafeEntry,
                    "tar links and special entries are not supported: #{entry.full_name}"
            end
          end
        end
      end
      root
    end

    def self.archive_limits
      {
        max_entries: MAX_ENTRIES,
        max_entry_bytes: MAX_ENTRY_BYTES,
        max_bytes: MAX_BYTES
      }
    end

    # @param name [String]
    # @return [Pathname]
    def self.safe_relative_path(name)
      raw = name.to_s
      if raw.empty? || raw.include?("\0") || path.absolute? || path.to_s == "." ||
         raw.split("/").include?("..")
        raise UnsafeEntry, "unsafe tar entry: #{name}"
      end

      Pathname.new(raw).cleanpath
    end

    def self.enforce_limits!(entries, entry_bytes, total_bytes, limits)
      if entries > limits.fetch(:max_entries)
        raise UnsafeEntry, "tar archive contains too many entries"
      end
      if entry_bytes > limits.fetch(:max_entry_bytes)
        raise UnsafeEntry, "tar entry exceeds the size limit"
      end
      return unless total_bytes > limits.fetch(:max_bytes)

      raise UnsafeEntry, "tar archive exceeds the expanded size limit"
    end

    def self.ensure_safe_target!(root, relative)
      current = root
      parts = relative.each_filename.to_a
      parts.each_with_index do |part, index|
        current = current.join(part)
        next unless File.exist?(current) || File.symlink?(current)

        stat = File.lstat(current)
        raise UnsafeEntry, "tar entry uses a symbolic link: #{relative}" if stat.symlink?
        if index < parts.length - 1 && !stat.directory?
          raise UnsafeEntry, "tar entry conflicts with a file: #{relative}"
        end
      end
    end
    private_class_method :safe_relative_path, :enforce_limits!, :ensure_safe_target!
  end
end
