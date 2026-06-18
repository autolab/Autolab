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

    # Packs every regular file under +staging_path+ into +destination+.
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
      paths = Dir.glob(root.join("**", "*").to_s, File::FNM_DOTMATCH).sort.filter_map do |name|
        path = Pathname.new(name)
        next if path == root || path.expand_path == output.expand_path

        raise UnsafeEntry, "symbolic links are not supported: #{path}" if path.symlink?
        next if path.directory?
        raise UnsafeEntry, "special files are not supported: #{path}" unless path.file?

        path
      end

      FileUtils.mkdir_p(output.dirname)
      File.open(output, "wb") do |stream|
        Gem::Package::TarWriter.new(stream) do |tar|
          paths.each do |path|
            size = path.lstat.size
            entries += 1
            bytes += size
            enforce_limits!(entries, size, bytes, limits)

            relative_path = path.relative_path_from(root).to_s
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
            if seen.any? { |seen_key, type| conflicting_entry?(seen_key, type, key) }
              raise UnsafeEntry, "conflicting tar entries: #{entry.full_name}"
            end

            seen[key] = entry.directory? ? :directory : :file
            target = root.join(relative).expand_path
            unless target.to_s == root.to_s || target.to_s.start_with?("#{root}#{File::SEPARATOR}")
              raise UnsafeEntry, "tar entry escapes package root: #{entry.full_name}"
            end

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
      path = Pathname.new(raw).cleanpath
      if raw.empty? || raw.include?("\0") || path.absolute? || path.to_s == "." ||
         raw.split("/").include?("..")
        raise UnsafeEntry, "unsafe tar entry: #{name}"
      end

      path
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
      relative.each_filename.with_index do |part, index|
        current = current.join(part)
        next unless File.exist?(current) || File.symlink?(current)

        stat = File.lstat(current)
        raise UnsafeEntry, "tar entry uses a symbolic link: #{relative}" if stat.symlink?
        if index < relative.each_filename.count - 1 && !stat.directory?
          raise UnsafeEntry, "tar entry conflicts with a file: #{relative}"
        end
      end
    end

    def self.conflicting_entry?(seen_key, type, key)
      (type == :file && key.start_with?("#{seen_key}/")) ||
        seen_key.start_with?("#{key}/")
    end
    private_class_method :safe_relative_path, :enforce_limits!, :ensure_safe_target!,
                         :conflicting_entry?
  end
end
