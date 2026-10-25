require "find"
require "rubygems/package"

module CourseArchive
  module Tarball
    MAX_ENTRIES = Integer(ENV.fetch("AUTOLAB_COURSE_TRANSFER_MAX_ENTRIES", "10000"))
    MAX_ENTRY_BYTES = Integer(ENV.fetch("AUTOLAB_COURSE_TRANSFER_MAX_ENTRY_BYTES", "268435456"))
    MAX_BYTES = Integer(ENV.fetch("AUTOLAB_COURSE_TRANSFER_MAX_BYTES", "1073741824"))

    def self.check_limits!(entries, size, total)
      raise Error, "Invalid archive file size" if size.negative?
      raise Error, "Archive contains too many entries" if entries > MAX_ENTRIES
      raise Error, "Archive file is too large" if size > MAX_ENTRY_BYTES
      raise Error, "Archive exceeds the size limit" if total > MAX_BYTES
    end

    def self.pack(root, destination)
      entries = total = 0
      File.open(destination, "wb") do |output|
        Gem::Package::TarWriter.new(output) do |tar|
          Find.find(root.to_s) do |entry|
            path = Pathname.new(entry)
            next if path == root
            raise Error, "Only regular files and directories can be exported" if
              path.symlink? || (!path.file? && !path.directory?)

            size = path.file? ? path.size : 0
            entries += 1
            total += size
            check_limits!(entries, size, total)
            name = path.relative_path_from(root).to_s
            if path.directory?
              tar.mkdir(name, 0o755)
            else
              tar.add_file_simple(name, path.stat.mode & 0o777, size) do |file|
                File.open(path, "rb") { |input| IO.copy_stream(input, file) }
              end
            end
          end
        end
      end
    end

    def self.unpack(source, root)
      entries = total = 0
      seen = Set.new
      File.open(source, "rb") do |input|
        Gem::Package::TarReader.new(input) do |tar|
          tar.each do |entry|
            name = Pathname.new(Paths.relative!(entry.full_name)).cleanpath
            raise Error, "Duplicate archive path: #{name}" unless seen.add?(name.to_s)
            raise Error, "Archive links and special files are not supported" unless
              entry.file? || entry.directory?

            entries += 1
            total += entry.size
            check_limits!(entries, entry.size, total)
            target = root.join(name)
            # Also rejects a parent that is a file or a pre-existing symbolic link.
            current = root
            raise Error, "Unsafe extraction directory" if root.symlink?

            name.each_filename do |part|
              current = current.join(part)
              raise Error, "Archive path uses a symbolic link" if current.symlink?
            end
            if entry.directory?
              FileUtils.mkdir_p(target)
            else
              FileUtils.mkdir_p(target.dirname)
              File.open(target, File::WRONLY | File::CREAT | File::EXCL, 0o600) do |output|
                copied = IO.copy_stream(entry, output)
                raise Error, "Truncated archive file: #{name}" unless copied == entry.size
              end
              target.chmod(0o600 | (entry.header.mode & 0o111))
            end
          end
        end
      end
    rescue Gem::Package::TarInvalidError, EOFError, SystemCallError => e
      raise Error, "Invalid tar archive: #{e.message}"
    end
  end
end
