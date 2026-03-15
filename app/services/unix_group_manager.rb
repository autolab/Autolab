require "open3"
require "fileutils"
require "etc"
require "net/http"
require "uri"
require "json"

##
# UnixGroupManager - Manages Unix groups and users for course filesystem permissions
#
# This service handles:
# - Creating/deleting Unix groups for courses
# - Creating Unix users for instructors/TAs
# - Adding/removing users from course groups
#
# Note: This requires Linux system tools (useradd, groupadd, etc.)
# On non-Linux systems (e.g., macOS), these operations will be skipped.
#
class UnixGroupManager
  # Check if system commands are available
  def self.system_commands_available?
    @system_commands_available ||= begin
      # Check if useradd and groupadd exist
      [Open3.capture3("which", "useradd"),
       Open3.capture3("which", "groupadd")].all? do |_stdout, _stderr, status|
        status.success?
      end
    rescue StandardError
      false
    end
  end

  # Check if we should skip Unix operations (e.g., development on macOS)
  def self.should_skip_operations?
    return false if delegate_enabled?
    return true unless system_commands_available?
    return true if Rails.env.development? && !ENV["ENABLE_UNIX_OPS"]

    false
  rescue StandardError
    true
  end

  def self.delegate_enabled?
    url = ENV["UNIX_OPS_DELEGATE_URL"]
    url && !url.strip.empty?
  end

  def self.delegate_secret
    secret = ENV["UNIX_OPS_SHARED_SECRET"]
    secret&.strip
  end

  def self.delegate_timeout
    (ENV["UNIX_OPS_DELEGATE_TIMEOUT"] || 10).to_i
  end

  def self.call_delegate(action, payload = {})
    return [false, {}] unless delegate_enabled?

    begin
      base_uri = URI.parse(ENV["UNIX_OPS_DELEGATE_URL"])
      jobs_uri = base_uri.dup
      if jobs_uri.path.nil? || jobs_uri.path.empty? || jobs_uri.path == "/"
        jobs_uri.path = "/jobs"
      end

      Rails.logger.info("UnixGroupManager.call_delegate: action=#{action}, payload=#{payload.inspect}")
      Rails.logger.info("UnixGroupManager.call_delegate: URL=#{jobs_uri}")

      request = Net::HTTP::Post.new(jobs_uri)
      request["Content-Type"] = "application/json"
      if delegate_secret.present?
        request["Authorization"] = "Bearer #{delegate_secret}"
      end
      request.body = JSON.dump(action:, payload:)

      http = Net::HTTP.new(jobs_uri.host, jobs_uri.port)
      http.use_ssl = jobs_uri.scheme == "https"
      http.open_timeout = delegate_timeout
      http.read_timeout = delegate_timeout

      Rails.logger.info("UnixGroupManager.call_delegate: Sending request to delegate...")
      response = http.request(request)
      body = response.body.to_s
      Rails.logger.info("UnixGroupManager.call_delegate: Response code=#{response.code}, body=#{body}")

      parsed = body.empty? ? {} : JSON.parse(body)
      success = response.code.to_i.between?(200, 299) && parsed.fetch("success", true)

      if success
        Rails.logger.info("UnixGroupManager.call_delegate: SUCCESS for action=#{action}")
      else
        Rails.logger.warn("UnixGroupManager delegate #{action} failed: #{response.code} #{body}")
      end

      [success, parsed]
    rescue StandardError => e
      Rails.logger.error("UnixGroupManager delegate #{action} error: #{e.class} - #{e.message}")
      Rails.logger.error("UnixGroupManager delegate #{action} backtrace: #{e.backtrace.first(5).join("\n")}")
      [false, {}]
    end
  end

  def self.delegate_action(action, payload = {})
    success, _parsed = call_delegate(action, payload)
    success
  end

  def self.delegate_query(action, payload = {})
    success, parsed = call_delegate(action, payload)
    return nil unless success

    parsed["data"]
  end

  # Get GID for a group name via delegate
  def self.get_group_gid(group_name)
    return nil if group_name.nil? || group_name.empty?

    if delegate_enabled?
      data = delegate_query("get_group_gid", group_name:)
      return data["gid"] if data.is_a?(Hash) && data.key?("gid")

      return nil
    end

    # Not using delegate - get locally
    begin
      Etc.getgrnam(group_name).gid
    rescue ArgumentError
      nil
    end
  end

  # Set group ownership on a file/directory via delegate
  # Optionally set owner as well (defaults to root)
  def self.chgrp_path(path, group_name, owner: "root")
    return false if path.nil? || group_name.nil? || group_name.empty?

    if delegate_enabled?
      Rails.logger.info("UnixGroupManager.chgrp_path: path=#{path}, group=#{group_name}, owner=#{owner || 'nil (keep current)'}")
      success, parsed = call_delegate("chgrp", path:, group_name:, owner:)
      if success
        Rails.logger.info("UnixGroupManager.chgrp_path: SUCCESS for #{path}")
      else
        Rails.logger.error("UnixGroupManager.chgrp_path: FAILED for #{path}, response: #{parsed.inspect}")
      end
      return success
    end

    # Not using delegate - do it locally
    begin
      group_info = Etc.getgrnam(group_name)
      owner_uid = owner ? Etc.getpwnam(owner).uid : nil
      File.chown(owner_uid, group_info.gid, path)
      true
    rescue StandardError => e
      Rails.logger.error("Failed to chgrp #{path} to #{group_name}: #{e.message}")
      false
    end
  end

  # Read file contents via delegate (useful when file/directory is locked down)
  def self.read_file_via_delegate(path)
    return nil if path.nil?

    if delegate_enabled?
      Rails.logger.info("UnixGroupManager.read_file_via_delegate: path=#{path}")
      success, parsed = call_delegate("read_file", path:)
      if success && parsed && parsed["content"]
        Rails.logger.info("UnixGroupManager.read_file_via_delegate: SUCCESS for #{path} (#{parsed['size']} bytes)")
        return parsed["content"]
      else
        Rails.logger.error("UnixGroupManager.read_file_via_delegate: FAILED for #{path}, response: #{parsed.inspect}")
        return nil
      end
    end

    # Not using delegate - try to read directly
    File.read(path) if File.readable?(path)
  end

  # Set file permissions via delegate
  def self.chmod_path(path, mode)
    return false if path.nil?

    if delegate_enabled?
      Rails.logger.info("UnixGroupManager.chmod_path: path=#{path}, mode=#{mode.to_s(8)} (#{mode})")
      success, parsed = call_delegate("chmod", path:, mode:)
      if success
        Rails.logger.info("UnixGroupManager.chmod_path: SUCCESS for #{path}")
      else
        Rails.logger.error("UnixGroupManager.chmod_path: FAILED for #{path}, response: #{parsed.inspect}")
      end
      return success
    end

    # Not using delegate - do it locally
    begin
      File.chmod(mode, path) unless File.symlink?(path)
      true
    rescue StandardError => e
      Rails.logger.error("Failed to chmod #{path} to #{mode.to_s(8)}: #{e.message}")
      false
    end
  end

  # Get UID for a username via delegate
  def self.get_user_uid(username)
    return nil if username.nil? || username.empty?

    if delegate_enabled?
      data = delegate_query("get_user_uid", username:)
      return data["uid"] if data.is_a?(Hash) && data.key?("uid")

      return nil
    end

    # Not using delegate - get locally
    begin
      Etc.getpwnam(username).uid
    rescue ArgumentError
      nil
    end
  end

  def self.user_exists?(username)
    return false if username.nil? || username.empty?

    if delegate_enabled?
      data = delegate_query("user_exists", username:)
      return data["value"] if data.is_a?(Hash) && data.key?("value")

      return data == true
    end

    stdout, _stderr, status = Open3.capture3("id", "-u", username)
    status.success?
  rescue StandardError
    false
  end

  def self.ensure_courses_symlink(home_dir)
    target = "/home/autolab/autolab-docker/Autolab/courses"
    return unless Dir.exist?(target)

    link_path = File.join(home_dir, "courses")
    begin
      if File.symlink?(link_path)
        current_target = begin
          File.readlink(link_path)
        rescue StandardError
          nil
        end
        return if current_target == target

        File.delete(link_path)
      elsif File.exist?(link_path)
        # Avoid overwriting an existing directory/file
        return
      end

      File.symlink(target, link_path)
    rescue StandardError => e
      Rails.logger.warn("Failed to create courses symlink at #{link_path}: #{e.message}")
    end
  end

  # Extract a safe Unix group name from course name
  def self.safe_group_name(course_name)
    return nil if course_name.nil? || course_name.empty?

    # Keep only alphanumeric, hyphens, dots, underscores
    safe = course_name.strip.gsub(/[^A-Za-z0-9._-]/, "-")
    # Limit length to 32 chars (Linux group name limit)
    safe = safe[0, 32]
    # Ensure it doesn't start with - or .
    safe = "grp-#{safe}" if safe.empty? || safe.start_with?("-", ".")
    safe
  end

  # Determine the Unix account that the Rails process is running under.
  # Allows overriding via AUTOLAB_SERVICE_USER for deployments where the
  # service user differs from the container login.
  def self.service_username
    env_user = ENV.fetch("AUTOLAB_SERVICE_USER", "").strip
    return env_user unless env_user.empty?

    Etc.getpwuid(Process.uid).name
  rescue StandardError => e
    Rails.logger.warn("UnixGroupManager.service_username failed: #{e.class} - #{e.message}")
    nil
  end

  # Extract a safe Unix username from email
  def self.login_from_email(email)
    return nil if email.nil? || email.empty?

    # Extract local part before @, lowercase it
    base = email.split("@").first.to_s.downcase
    # Keep only alphanumeric, hyphens, underscores
    base = base.gsub(/[^a-z0-9_-]/, "-")
    # Ensure it starts with a letter
    base = "u#{base}" unless base.match?(/\A[a-z]/)
    # Limit length
    base = base[0, 32]
    base = "uuser" if base.empty?
    base
  end

  # Ensure a Unix group exists, creating it if necessary
  def self.ensure_group(group_name)
    return false if group_name.nil? || group_name.empty?
    if delegate_enabled?
      return delegate_action("ensure_group", group_name:)
    end
    return true if should_skip_operations? # Skip on non-Linux systems

    begin
      # Check if group exists
      stdout, stderr, status = Open3.capture3("getent", "group", group_name)
      return true if status.success?

      # Create the group
      stdout, stderr, status = Open3.capture3("groupadd", group_name)
      if status.success?
        Rails.logger.info("Created Unix group: #{group_name}")
        true
      else
        Rails.logger.error("Failed to create group #{group_name}: #{stderr}")
        false
      end
    rescue StandardError => e
      Rails.logger.warn("Skipping group creation for #{group_name}: #{e.message}")
      false
    end
  end

  # Remove a Unix group if it exists and has no members (optional: force delete)
  def self.remove_group(group_name, force: false)
    return false if group_name.nil? || group_name.empty?
    if delegate_enabled?
      return delegate_action("remove_group", group_name:, force:)
    end

    # Check if group exists
    stdout, stderr, status = Open3.capture3("getent", "group", group_name)
    return true unless status.success? # Already doesn't exist

    if force
      # Force delete (use with caution)
      stdout, stderr, status = Open3.capture3("groupdel", group_name)
      if status.success?
        Rails.logger.info("Removed Unix group: #{group_name}")
        true
      else
        Rails.logger.error("Failed to remove group #{group_name}: #{stderr}")
        false
      end
    else
      # Check if group has members
      group_info = stdout.strip.split(":")
      members = group_info[3] # Fourth field contains member list
      if members.nil? || members.empty?
        stdout, stderr, status = Open3.capture3("groupdel", group_name)
        if status.success?
          Rails.logger.info("Removed Unix group: #{group_name}")
          true
        else
          Rails.logger.error("Failed to remove group #{group_name}: #{stderr}")
          false
        end
      else
        Rails.logger.warn("Group #{group_name} has members, not removing")
        false
      end
    end
  end

  # Ensure a Unix user exists, creating it if necessary
  def self.ensure_user(username, email: nil)
    return false if username.nil? || username.empty?
    if delegate_enabled?
      return delegate_action("ensure_user", username:, email:)
    end
    return true if should_skip_operations? # Skip on non-Linux systems

    begin
      # Check if user exists
      stdout, stderr, status = Open3.capture3("id", "-u", username)
      if status.success?
        # User exists, ensure home directory and .ssh directory exist
        setup_user_home(username)
        return true
      end

      # Determine whether a primary group with the same name already exists so we can re-use it
      group_exists = false
      begin
        _, _, group_status = Open3.capture3("getent", "group", username)
        group_exists = group_status.success?
      rescue StandardError => e
        Rails.logger.warn("Unable to check existing group for #{username}: #{e.message}")
      end

      # Create user with home directory and bash shell, no password, disabled password login
      # Use -p '*' to lock the password (works on BusyBox and GNU useradd)
      cmd = ["useradd", "-m", "-s", "/bin/bash", "-p", "*"]
      cmd += ["-g", username] if group_exists
      cmd << "-c" << email if email
      cmd << username

      stdout, stderr, status = Open3.capture3(*cmd)
      if status.success?
        Rails.logger.info("Created Unix user: #{username}")
        # Set up home directory and .ssh
        setup_user_home(username)
        true
      else
        Rails.logger.error("Failed to create user #{username}: #{stderr}")
        false
      end
    rescue Errno::ENOENT => e
      # Command not found (e.g., on macOS)
      Rails.logger.warn("Skipping user creation for #{username}: System commands not available (#{e.message})")
      false
    rescue StandardError => e
      Rails.logger.warn("Skipping user creation for #{username}: #{e.message}")
      false
    end
  end

  # Set up user's home directory with .ssh directory and proper permissions
  def self.setup_user_home(username)
    return false if username.nil? || username.empty?
    if delegate_enabled?
      return delegate_action("setup_user_home", username:)
    end
    return true if should_skip_operations? # Skip on non-Linux systems

    begin
      # Get home directory
      stdout, stderr, status = Open3.capture3("getent", "passwd", username)
      return false unless status.success?

      home_dir = stdout.split(":")[5]
      return false if home_dir.nil? || home_dir.empty?

      # Ensure home directory exists
      FileUtils.mkdir_p(home_dir) unless Dir.exist?(home_dir)

      # Create .ssh directory with proper permissions (700)
      ssh_dir = File.join(home_dir, ".ssh")
      FileUtils.mkdir_p(ssh_dir) unless Dir.exist?(ssh_dir)
      File.chmod(0o700, ssh_dir)

      # Get user info - handle case where user might not exist yet
      begin
        user_info = Etc.getpwnam(username)
        File.chown(user_info.uid, user_info.gid, ssh_dir)

        # Create authorized_keys file if it doesn't exist (600)
        authorized_keys = File.join(ssh_dir, "authorized_keys")
        FileUtils.touch(authorized_keys) unless File.exist?(authorized_keys)
        File.chmod(0o600, authorized_keys)
        File.chown(user_info.uid, user_info.gid, authorized_keys)
      rescue ArgumentError
        # User doesn't exist in passwd - that's ok, skip ownership changes
        Rails.logger.warn("User #{username} not found in passwd, skipping ownership changes")
      end

      ensure_courses_symlink(home_dir)

      true
    rescue StandardError => e
      Rails.logger.warn("Failed to setup home for #{username}: #{e.message}")
      false
    end
  end

  # Add a user to a group
  def self.add_user_to_group(username, group_name)
    return false if username.nil? || group_name.nil?
    return false if username.empty? || group_name.empty?
    if delegate_enabled?
      return delegate_action("add_user_to_group", username:, group_name:)
    end

    # Check if user is already in group
    stdout, stderr, status = Open3.capture3("id", "-nG", username)
    if status.success? && stdout.split.include?(group_name)
      return true # Already a member
    end

    # Add user to group
    stdout, stderr, status = Open3.capture3("usermod", "-a", "-G", group_name, username)
    if status.success?
      Rails.logger.info("Added #{username} to group #{group_name}")
      true
    else
      Rails.logger.error("Failed to add #{username} to group #{group_name}: #{stderr}")
      false
    end
  end

  # Remove a user from a group
  def self.remove_user_from_group(username, group_name)
    return false if username.nil? || group_name.nil?
    return false if username.empty? || group_name.empty?
    if delegate_enabled?
      return delegate_action("remove_user_from_group", username:, group_name:)
    end

    # Remove user from group using gpasswd
    stdout, stderr, status = Open3.capture3("gpasswd", "-d", username, group_name)
    if status.success?
      Rails.logger.info("Removed #{username} from group #{group_name}")
      true
    else
      Rails.logger.error("Failed to remove #{username} from group #{group_name}: #{stderr}")
      false
    end
  end

  # Create group for a course (do not create users - users created on-demand when SSH key is added)
  def self.setup_course_group(course)
    group_name = safe_group_name(course.name)
    return false unless group_name

    # Create the group only (no users yet)
    ensure_group(group_name)

    # Note: Users are NOT created here. They are created on-demand when:
    # 1. User adds first SSH key via web UI
    # 2. At that point, they are added to all course groups they're staff in
    true
  end

  # Update group membership when staff is added/removed
  # Note: Does NOT create Unix user - users are created on-demand when SSH key is added
  def self.update_course_staff_membership(course, user, is_staff: true)
    group_name = safe_group_name(course.name)
    return false unless group_name

    # Ensure group exists
    return false unless ensure_group(group_name)

    username = login_from_email(user.email)
    return false unless username

    # Check if user exists (only add to group if user already exists)
    # User is created on-demand when first SSH key is added
    return true unless user_exists?(username) # User doesn't exist yet - that's ok

    if is_staff
      # Add existing user to group
      add_user_to_group(username, group_name)
    else
      # Remove user from group (but don't delete user)
      remove_user_from_group(username, group_name)
    end

    true
  end

  # Provision SSH public key to user's authorized_keys file
  def self.provision_ssh_key(username, public_key, email: nil)
    return false if username.nil? || username.empty? || public_key.nil? || public_key.empty?

    if delegate_enabled?
      return delegate_action("provision_ssh_key", username:, public_key:,
                                                  email:)
    end

    # In development or when system commands aren't available, just log and succeed
    if should_skip_operations?
      Rails.logger.info("Skipping SSH key provisioning for #{username} (development mode or system commands unavailable)")
      return true
    end

    # Ensure user exists and home is set up
    ensure_user(username, email:)
    setup_user_home(username)

    # Get home directory
    stdout, stderr, status = Open3.capture3("getent", "passwd", username)
    return false unless status.success?

    home_dir = stdout.split(":")[5]
    return false if home_dir.nil? || home_dir.empty?

    authorized_keys = File.join(home_dir, ".ssh", "authorized_keys")
    return false unless File.exist?(authorized_keys)

    # Read existing keys
    existing_keys = []
    if File.exist?(authorized_keys) && File.size(authorized_keys) > 0
      existing_keys = File.readlines(authorized_keys).map(&:strip).reject(&:empty?)
    end

    # Add new key if not already present
    key_line = public_key.strip
    unless existing_keys.include?(key_line)
      File.open(authorized_keys, "a") do |f|
        f.puts key_line
      end
      File.chmod(0o600, authorized_keys)
      user_info = Etc.getpwnam(username)
      File.chown(user_info.uid, user_info.gid, authorized_keys)
      Rails.logger.info("Added SSH key for #{username}")
    end

    true
  rescue StandardError => e
    Rails.logger.error("Failed to provision SSH key for #{username}: #{e}")
    false
  end

  # Remove SSH key from authorized_keys by fingerprint
  def self.deprovision_ssh_key(username, fingerprint)
    return false if username.nil? || username.empty? || fingerprint.nil? || fingerprint.empty?
    if delegate_enabled?
      return delegate_action("deprovision_ssh_key", username:, fingerprint:)
    end

    # Get home directory
    stdout, stderr, status = Open3.capture3("getent", "passwd", username)
    return false unless status.success?

    home_dir = stdout.split(":")[5]
    return false if home_dir.nil? || home_dir.empty?

    authorized_keys = File.join(home_dir, ".ssh", "authorized_keys")
    return false unless File.exist?(authorized_keys)

    # Read existing keys and filter out the one with matching fingerprint
    existing_keys = File.readlines(authorized_keys).map(&:strip).reject(&:empty?)

    # Find key with matching fingerprint
    require "digest"
    require "base64"
    filtered_keys = existing_keys.reject do |key_line|
      parts = key_line.split(/\s+/, 3)
      next false if parts.length < 2

      begin
        key_data = parts[1]
        decoded = Base64.decode64(key_data)
        key_fingerprint = Digest::SHA256.hexdigest(decoded)
        key_fingerprint == fingerprint
      rescue StandardError
        false
      end
    end

    # Write back filtered keys
    File.open(authorized_keys, "w") do |f|
      filtered_keys.each { |key| f.puts key }
    end
    File.chmod(0o600, authorized_keys)
    user_info = Etc.getpwnam(username)
    File.chown(user_info.uid, user_info.gid, authorized_keys)

    Rails.logger.info("Removed SSH key for #{username}")
    true
  rescue StandardError => e
    Rails.logger.error("Failed to deprovision SSH key for #{username}: #{e}")
    false
  end

  # Provision multiple SSH keys (replaces all keys)
  def self.provision_ssh_keys(username, public_keys, email: nil)
    return false if username.nil? || username.empty?

    if delegate_enabled?
      return delegate_action("provision_ssh_keys", username:, public_keys:,
                                                   email:)
    end

    # Ensure user exists and home is set up
    ensure_user(username, email:)
    setup_user_home(username)

    # Get home directory
    stdout, stderr, status = Open3.capture3("getent", "passwd", username)
    return false unless status.success?

    home_dir = stdout.split(":")[5]
    return false if home_dir.nil? || home_dir.empty?

    authorized_keys = File.join(home_dir, ".ssh", "authorized_keys")
    return false unless File.exist?(authorized_keys)

    # Write all keys
    File.open(authorized_keys, "w") do |f|
      public_keys.each do |key|
        f.puts key.strip if key && !key.strip.empty?
      end
    end
    File.chmod(0o600, authorized_keys)
    user_info = Etc.getpwnam(username)
    File.chown(user_info.uid, user_info.gid, authorized_keys)

    Rails.logger.info("Provisioned #{public_keys.length} SSH keys for #{username}")
    true
  rescue StandardError => e
    Rails.logger.error("Failed to provision SSH keys for #{username}: #{e}")
    false
  end

  # Delete a Unix user (removes home directory and all data)
  def self.delete_user(username, remove_home: true)
    return false if username.nil? || username.empty?
    if delegate_enabled?
      return delegate_action("delete_user", username:, remove_home:)
    end

    # Check if user exists
    stdout, stderr, status = Open3.capture3("id", "-u", username)
    return true unless status.success? # Already doesn't exist

    cmd = ["userdel"]
    cmd << "-r" if remove_home # Remove home directory and mail spool
    cmd << username

    stdout, stderr, status = Open3.capture3(*cmd)
    if status.success?
      Rails.logger.info("Deleted Unix user: #{username}")
      true
    else
      Rails.logger.error("Failed to delete user #{username}: #{stderr}")
      false
    end
  end

  # Check if a user is a member of a group inside the container's local /etc/group
  def self.local_group_member?(username, group_name)
    return false if username.blank? || group_name.blank?

    # We check the local /etc/group file directly
    stdout, _, status = Open3.capture3("grep", "^#{group_name}:", "/etc/group")
    return false unless status.success?

    # Check if the username is in the comma-separated list at the end of the line
    members = stdout.strip.split(":")[3]
    members&.split(",")&.include?(username) || false
  rescue StandardError
    false
  end

  # Force the container to recognize a group membership without a restart
  def self.ensure_local_group_membership(username, group_name, gid_hint: nil)
    return true if local_group_member?(username, group_name)

    # Use the provided GID or look it up via the delegate
    gid = gid_hint || get_group_gid(group_name)
    unless gid
      Rails.logger.error("UnixGroupManager.ensure_local_group_membership: Could not find GID
         for #{group_name}")
      return false
    end

    Rails.logger.info("UnixGroupManager: Syncing #{username} to local group #{group_name}
         (GID: #{gid})")

    begin
      # 1. If group doesn't exist locally, create the line
      if system("grep -q '^#{group_name}:' /etc/group")
        # 2. Group exists, but user is missing - append user to the end of the line
        # Uses sed to find the line starting with group_name and append the username
        Open3.capture3("sed", "-i", "/^#{group_name}:/ s/$/#{username}/", "/etc/group")
      else
        # Direct append to /etc/group (Requires Rails to have write access to /etc/group)
        Open3.capture3("sh", "-c", "echo '#{group_name}:x:#{gid}:#{username}' >> /etc/group")
      end

      # Verify the change worked
      local_group_member?(username, group_name)
    rescue StandardError => e
      Rails.logger.error("UnixGroupManager.ensure_local_group_membership failed: #{e.message}")
      false
    end
  end
end
