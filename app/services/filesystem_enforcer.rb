require "etc"
require "pathname"
require_relative "./unix_group_manager"

class FilesystemEnforcer
  GROUP     = ENV.fetch("COURSE_FS_GROUP", "autolab") # fallback only
  MODE_DIR  = 0o2770  # drwxrws---
  MODE_FILE = 0o660   # -rw-rw----

  # Enforce owner-group & perms on a single path
  # Optionally pass group_name to avoid database lookup
  # Only operates on paths under courses/ folder - shared directories like courseConfig/assessmentConfig are excluded
  def self.fix_path(path, group_name: nil)
    return unless File.exist?(path)
    
    # Safety guard: FilesystemEnforcer should only touch files in courses/ folder
    # Shared directories like courseConfig/assessmentConfig need different permissions
    abs_path = Pathname.new(path).expand_path.to_s
    courses_root = Rails.root.join("courses").expand_path.to_s + File::SEPARATOR
    unless abs_path.start_with?(courses_root)
      Rails.logger.warn("FilesystemEnforcer: Skipping #{path} - only files under courses/ should be enforced") if Rails.logger
      return
    end
    
    grp = group_name || inferred_group(path) || GROUP

    begin
      # When using delegate, always use delegate chgrp (runs on host with proper privileges)
      # The Rails container doesn't have permission to chown files
      # Set owner to root for directories to ensure consistent ownership
      if UnixGroupManager.delegate_enabled?
        owner = File.directory?(path) ? "root" : nil  # Set root owner for directories, keep current for files
        if UnixGroupManager.chgrp_path(path, grp, owner: owner)
          # Success via delegate
        else
          # Log but don't raise - FilesystemEnforcer should be non-fatal
          Rails.logger.warn("FilesystemEnforcer: Delegate chgrp failed for #{grp} on #{path}") if Rails.logger
        end
      else
        # Not using delegate - look up locally and chown (only works if process has permission)
        gid = Etc.getgrnam(grp).gid
        File.chown(nil, gid, path)
      end
    rescue StandardError => e
      # group not present or chown failed (non-fatal, but log it)
      Rails.logger.warn("FilesystemEnforcer: Could not set group #{grp} on #{path}: #{e.message}") if Rails.logger
    end

    begin
      # Always enforce 2770 for directories, never allow world access
      mode = File.directory?(path) ? 0o2770 : MODE_FILE
      # Skip symlinks to avoid lchmod issues on some platforms
      unless File.symlink?(path)
        # When using delegate, use delegate chmod (runs on host with proper privileges)
        # The Rails container might not have permission to chmod files owned by root
        if UnixGroupManager.delegate_enabled?
          unless UnixGroupManager.chmod_path(path, mode)
            Rails.logger.warn("FilesystemEnforcer: Delegate chmod failed for mode #{mode.to_s(8)} on #{path}") if Rails.logger
          end
        else
          # Not using delegate - do it locally (only works if process has permission)
          File.chmod(mode, path)
        end
      end
    rescue StandardError => e
      # ignore chmod on odd/special files, but log it
      Rails.logger.warn("FilesystemEnforcer: Could not chmod #{path}: #{e.message}") if Rails.logger
    end
  end

  # Enforce recursively (includes root)
  def self.fix_tree(root)
    return unless File.exist?(root)
    Rails.logger.info("FilesystemEnforcer.fix_tree: Starting on #{root}") if Rails.logger
    # Include dotfiles, skip '.' and '..'
    Dir.glob(File.join(root, "**", "*"), File::FNM_DOTMATCH).each do |p|
      base = File.basename(p)
      next if base == "." || base == ".."
      fix_path(p)
    end
    # Fix root directory last (this sets it to root:<group> with 2770)
    Rails.logger.info("FilesystemEnforcer.fix_tree: Fixing root directory #{root}") if Rails.logger
    fix_path(root)
    Rails.logger.info("FilesystemEnforcer.fix_tree: Completed on #{root}") if Rails.logger
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
      # When using delegate, check via delegate; otherwise check locally
      if UnixGroupManager.delegate_enabled?
        gid = UnixGroupManager.get_group_gid(group_name)
        return group_name if gid # Group exists on host
      else
        Etc.getgrnam(group_name) # raises if missing
        return group_name
      end
      nil
    rescue StandardError
      # Fallback: try using directory name directly as group name
      if UnixGroupManager.delegate_enabled?
        gid = UnixGroupManager.get_group_gid(course_dir_name)
        return course_dir_name if gid
      else
        begin
          Etc.getgrnam(course_dir_name)
          return course_dir_name
        rescue StandardError
          nil
        end
      end
      nil
    end
  end

  private_class_method :inferred_group
end