require "etc"
require "pathname"
require_relative "./unix_group_manager"

class FilesystemEnforcer
  GROUP     = ENV.fetch("COURSE_FS_GROUP", "autolab") # fallback only
  MODE_DIR  = 0o2770  # drwxrws---
  MODE_FILE = 0o660   # -rw-rw----

  # Enforce owner-group & perms on a single path
  # Optionally pass group_name to avoid database lookup
  def self.fix_path(path, group_name: nil)
    return unless File.exist?(path)
    grp = group_name || inferred_group(path) || GROUP

    begin
      gid = Etc.getgrnam(grp).gid
      File.chown(nil, gid, path)           # keep owner as-is, set group
    rescue StandardError => e
      # group not present or chown failed (non-fatal, but log it)
      Rails.logger.warn("FilesystemEnforcer: Could not set group #{grp} on #{path}: #{e.message}") if Rails.logger
    end

    begin
      mode = File.directory?(path) ? MODE_DIR : MODE_FILE
      # Skip symlinks to avoid lchmod issues on some platforms
      File.chmod(mode, path) unless File.symlink?(path)
    rescue StandardError => e
      # ignore chmod on odd/special files, but log it
      Rails.logger.warn("FilesystemEnforcer: Could not chmod #{path}: #{e.message}") if Rails.logger
    end
  end

  # Enforce recursively (includes root)
  def self.fix_tree(root)
    return unless File.exist?(root)
    # Include dotfiles, skip '.' and '..'
    Dir.glob(File.join(root, "**", "*"), File::FNM_DOTMATCH).each do |p|
      base = File.basename(p)
      next if base == "." || base == ".."
      fix_path(p)
    end
    fix_path(root)
  end

  # Map filesystem path → course group (folder name under Rails.root/courses)
  # The directory name matches the course name, and we need to find the Unix group
  # which may be normalized via safe_group_name
  def self.inferred_group(path)
    courses_root = Rails.root.join("courses").expand_path.to_s + File::SEPARATOR
    abs = Pathname.new(path).expand_path.to_s
    return nil unless abs.start_with?(courses_root)

    # Get the course directory name (first component under courses/)
    course_dir_name = Pathname.new(abs).relative_path_from(Pathname.new(courses_root)).each_filename.first
    return nil if course_dir_name.nil? || course_dir_name.empty?

    # Try to find the Course model by directory name
    # The directory name should match the course.name field
    begin
      course = Course.find_by(name: course_dir_name)
      return nil unless course

      # Get the Unix group name (normalized via safe_group_name)
      group_name = UnixGroupManager.safe_group_name(course.name)
      return nil unless group_name

      # Verify the group actually exists
      Etc.getgrnam(group_name) # raises if missing
      group_name
    rescue StandardError
      # Fallback: try using directory name directly as group name
      begin
        Etc.getgrnam(course_dir_name)
        course_dir_name
      rescue StandardError
        nil
      end
    end
  end

  private_class_method :inferred_group
end