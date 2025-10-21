require "etc"
require "pathname"

class FilesystemEnforcer
  GROUP     = ENV.fetch("COURSE_FS_GROUP", "autolab") # fallback
  MODE_DIR  = 0o2775  # drwxrwsr-x (setgid)
  MODE_FILE = 0o664   # -rw-rw-r--

  def self.fix_path(path)
    return unless File.exist?(path)
    grp = inferred_group(path) || GROUP
    begin
      File.chown(nil, Etc.getgrnam(grp).gid, path)
    rescue StandardError
      # ignore chown issues, still try chmod
    end
    begin
      File.chmod(File.directory?(path) ? MODE_DIR : MODE_FILE, path)
    rescue StandardError
      # ignore chmod issues (symlinks/special files)
    end
  end

  def self.fix_tree(root)
    return unless File.exist?(root)
    Dir.glob("#{root}/**/*", File::FNM_DOTMATCH).each do |p|
      next if %w[. ..].include?(File.basename(p))
      fix_path(p)
    end
    fix_path(root) # enforce on the root itself too
  end

  def self.inferred_group(path)
    courses_root = Rails.root.join("courses").expand_path.to_s + File::SEPARATOR
    abs = Pathname.new(path).expand_path.to_s
    return nil unless abs.start_with?(courses_root)
    course = Pathname.new(abs).relative_path_from(Pathname.new(courses_root)).each_filename.first
    return nil if course.nil? || course.empty?
    Etc.getgrnam(course) # will raise if missing
    course
  rescue StandardError
    nil
  end

  private_class_method :inferred_group
end