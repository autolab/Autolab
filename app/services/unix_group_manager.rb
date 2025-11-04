require "open3"
require "fileutils"
require "etc"

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
      [Open3.capture3("which", "useradd"), Open3.capture3("which", "groupadd")].all? do |stdout, stderr, status|
        status.success?
      end
    rescue StandardError
      false
    end
  end

  # Check if we should skip Unix operations (e.g., development on macOS)
  def self.should_skip_operations?
    return true unless system_commands_available?
    return true if Rails.env.development? && !ENV["ENABLE_UNIX_OPS"]
    return false
  rescue StandardError
    true
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
    return true if should_skip_operations? # Skip on non-Linux systems

    begin
      # Check if user exists
      stdout, stderr, status = Open3.capture3("id", "-u", username)
      if status.success?
        # User exists, ensure home directory and .ssh directory exist
        setup_user_home(username)
        return true
      end

      # Create user with home directory and bash shell, no password, disabled password login
      # Use -p '*' to lock the password (works on BusyBox and GNU useradd)
      cmd = ["useradd", "-m", "-s", "/bin/bash", "-p", "*"]
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
        File.chown(nil, user_info.uid, ssh_dir)

        # Create authorized_keys file if it doesn't exist (600)
        authorized_keys = File.join(ssh_dir, "authorized_keys")
        FileUtils.touch(authorized_keys) unless File.exist?(authorized_keys)
        File.chmod(0o600, authorized_keys)
        File.chown(nil, user_info.uid, authorized_keys)
      rescue ArgumentError
        # User doesn't exist in passwd - that's ok, skip ownership changes
        Rails.logger.warn("User #{username} not found in passwd, skipping ownership changes")
      end

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
    stdout, stderr, status = Open3.capture3("id", "-u", username)
    return true unless status.success? # User doesn't exist yet - that's ok, will be created with SSH key

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
    
    # In development or when system commands aren't available, just log and succeed
    if should_skip_operations?
      Rails.logger.info("Skipping SSH key provisioning for #{username} (development mode or system commands unavailable)")
      return true
    end

    # Ensure user exists and home is set up
    ensure_user(username, email: email)
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
      uid = Etc.getpwnam(username).uid
      File.chown(nil, uid, authorized_keys)
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
    uid = Etc.getpwnam(username).uid
    File.chown(nil, uid, authorized_keys)

    Rails.logger.info("Removed SSH key for #{username}")
    true
  rescue StandardError => e
    Rails.logger.error("Failed to deprovision SSH key for #{username}: #{e}")
    false
  end

  # Provision multiple SSH keys (replaces all keys)
  def self.provision_ssh_keys(username, public_keys, email: nil)
    return false if username.nil? || username.empty?

    # Ensure user exists and home is set up
    ensure_user(username, email: email)
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
    uid = Etc.getpwnam(username).uid
    File.chown(nil, uid, authorized_keys)

    Rails.logger.info("Provisioned #{public_keys.length} SSH keys for #{username}")
    true
  rescue StandardError => e
    Rails.logger.error("Failed to provision SSH keys for #{username}: #{e}")
    false
  end

  # Delete a Unix user (removes home directory and all data)
  def self.delete_user(username, remove_home: true)
    return false if username.nil? || username.empty?

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
end

