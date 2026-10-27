module CourseArchive
  module ImportFiles
    # Shared destination directories must be writable before claiming the new
    # course and generating configs. Leave existing course subdirectories alone.
    def self.prepare_directory(path)
      raise Error, "Import directory cannot be a symbolic link: #{path}" if path.symlink?

      begin
        FileUtils.mkdir_p(path)
      rescue Errno::EACCES, Errno::EPERM
        raise unless UnixGroupManager.delegate_enabled? &&
                     UnixGroupManager.mkdir_p_via_delegate(path.to_s, mode: 0o755)
      end
      return if path.writable? && path.executable?

      raise Errno::EACCES, "Import directory is not writable: #{path}" unless
        UnixGroupManager.delegate_enabled?

      mode = (path.stat.mode & 0o7777) | 0o700
      # Use the Rails numeric UID, as in normal course config initialization.
      # Preserve the directory's group and its existing group/other permissions.
      changed = UnixGroupManager.delegate_action("chown", path: path.to_s,
                                                          owner: Process.uid.to_s) &&
                UnixGroupManager.chmod_path(path.to_s, mode)
      raise Errno::EACCES, "Could not prepare import directory: #{path}" unless
        changed && path.writable? && path.executable?
    end

    def self.remove(path, recursive: false)
      recursive ? FileUtils.remove_entry(path) : File.unlink(path)
    rescue Errno::ENOENT
      nil
    rescue Errno::EACCES, Errno::EPERM
      raise unless UnixGroupManager.delegate_enabled? &&
                   UnixGroupManager.delegate_action("delete_path", path: path.to_s, recursive:)
    end
  end
end
