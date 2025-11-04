##
# SSHKey - Stores SSH public keys for users to enable SSH access
#
require_relative "../services/unix_group_manager"

class SshKey < ApplicationRecord
  belongs_to :user

  validates :public_key, presence: true
  validates :user_id, presence: true
  validate :valid_public_key_format
  validate :unique_key_per_user

  before_save :parse_key_metadata
  after_save :provision_key
  after_destroy :deprovision_key

  # Parse SSH key to extract type, comment, and fingerprint
  def parse_key_metadata
    # Format: "ssh-rsa AAAA... comment" or "ssh-ed25519 AAAA... comment"
    parts = public_key.strip.split(/\s+/, 3)
    return if parts.length < 2

    self.key_type = parts[0]
    self.comment = parts[2] if parts.length > 2
    self.fingerprint = calculate_fingerprint
  end

  # Calculate SHA256 fingerprint of the public key
  def calculate_fingerprint
    # Extract the key data (second part)
    parts = public_key.strip.split(/\s+/, 3)
    return nil if parts.length < 2

    key_data = parts[1]
    # Decode base64 and calculate SHA256
    require "digest"
    require "base64"
    decoded = Base64.decode64(key_data)
    Digest::SHA256.hexdigest(decoded)
  rescue StandardError
    nil
  end

  # Provision the key to the user's authorized_keys file
  # This is where Unix users are created - on-demand when first SSH key is added
  def provision_key
    return unless active
    return unless user

    username = UnixGroupManager.login_from_email(user.email)
    return unless username

    # This is where we create the Unix user - on-demand when SSH key is added
    # This may fail silently in development (e.g., on macOS)
    begin
      # Create Unix user (if doesn't exist) - this is the ONLY place users are created
      UnixGroupManager.ensure_user(username, email: user.email)
      
      # Provision SSH key
      UnixGroupManager.provision_ssh_key(username, public_key, user.email)
      
      # Add user to all course groups they're staff in (now that user exists)
      user.course_user_data.where(instructor: true)
          .or(user.course_user_data.where(course_assistant: true))
          .includes(:course).find_each do |cud|
        course = cud.course
        UnixGroupManager.update_course_staff_membership(course, user, is_staff: true)
      end
    rescue StandardError => e
      # Log but don't fail - in development, Unix ops might not be available
      Rails.logger.warn("Could not provision SSH key for #{username}: #{e.message}")
      # Still mark as saved in DB even if Unix provisioning failed
    end
  end

  # Remove the key from authorized_keys
  def deprovision_key
    return unless user

    username = UnixGroupManager.login_from_email(user.email)
    return unless username

    UnixGroupManager.deprovision_ssh_key(username, fingerprint)
    
    # Re-provision remaining active keys
    remaining_keys = user.ssh_keys.where(active: true).where.not(id: id)
    if remaining_keys.any?
      keys_data = remaining_keys.pluck(:public_key)
      UnixGroupManager.provision_ssh_keys(username, keys_data, user.email)
    end
  end

  # Re-provision all active keys for a user
  def self.provision_all_for_user(user)
    return unless user

    username = UnixGroupManager.login_from_email(user.email)
    return unless username

    # Ensure user exists and has home directory set up
    UnixGroupManager.ensure_user(username, email: user.email)

    active_keys = where(user: user, active: true)
    keys_data = active_keys.pluck(:public_key)
    UnixGroupManager.provision_ssh_keys(username, keys_data, user.email)
  end

private

  def valid_public_key_format
    return if public_key.blank?

    # Basic validation: should start with key type
    valid_types = %w[ssh-rsa ssh-ed25519 ecdsa-sha2-nistp256 ecdsa-sha2-nistp384 ecdsa-sha2-nistp521 ssh-dss]
    parts = public_key.strip.split(/\s+/, 2)

    unless valid_types.include?(parts[0])
      errors.add(:public_key, "must be a valid SSH public key (ssh-rsa, ssh-ed25519, or ecdsa)")
      return
    end

    # Should have key data
    if parts.length < 2 || parts[1].blank?
      errors.add(:public_key, "must include the key data")
      return
    end

    # Validate base64 encoding
    begin
      require "base64"
      Base64.decode64(parts[1])
    rescue ArgumentError
      errors.add(:public_key, "contains invalid base64 data")
    end
  end

  def unique_key_per_user
    return if public_key.blank?

    # Check if another key with the same fingerprint exists for this user
    fingerprint = calculate_fingerprint
    return unless fingerprint

    existing = SshKey.where(user_id: user_id, fingerprint: fingerprint)
                    .where.not(id: id)
                    .exists?

    errors.add(:public_key, "already exists for this user") if existing
  end
end
