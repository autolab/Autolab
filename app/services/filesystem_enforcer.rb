# app/services/filesystem_enforcer.rb
class FilesystemEnforcer
    OWNER  = ENV.fetch("COURSE_FS_OWNER", "ubuntu")
    GROUP  = ENV.fetch("COURSE_FS_GROUP", "autolab")
    MODE_DIR  = 0o2775  # drwxrwsr-x
    MODE_FILE = 0o664   # -rw-rw-r--
  
    def self.fix_path(path)
      return unless File.exist?(path)
      File.chown(nil, Etc.getgrnam(GROUP).gid, path) rescue nil
      File.chmod(File.directory?(path) ? MODE_DIR : MODE_FILE, path) rescue nil
    end
  
    def self.fix_tree(root)
      Dir.glob("#{root}/**/*", File::FNM_DOTMATCH).each { |p| fix_path(p) }
    end
  end
  