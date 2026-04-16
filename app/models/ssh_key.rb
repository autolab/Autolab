##
# SSHKey - Stores SSH public keys for users to enable SSH access
#
require_relative "../services/unix_group_manager"

class SshKey < ApplicationRecord
  class ProvisioningError < StandardError; end

  belongs_to :user

  validates :public_key, presence: true
  validates :user_id, presence: true
  validate :valid_public_key_format
  validate :unique_key_per_user

  before_save :parse_key_metadata

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

  # Re-provision all active keys for a user, raising if Unix sync fails
  def self.provision_all_for_user(user)
    raise ProvisioningError, "User is required" unless user

    username = ensure_unix_username!(user)

    return true if UnixGroupManager.should_skip_operations?

    unless UnixGroupManager.ensure_user(username, email: user.email)
      raise ProvisioningError, "Failed to ensure Unix account for #{username}"
    end

    sync_course_memberships!(user)

    active_keys = where(user:, active: true)
    keys_data = active_keys.pluck(:public_key)

    unless UnixGroupManager.provision_ssh_keys(username, keys_data, email: user.email)
      raise ProvisioningError, "Failed to update authorized_keys for #{username}"
    end

    true
  end

private

  def valid_public_key_format
    return if public_key.blank?

    # Basic validation: should start with key type
    valid_types = %w[ssh-rsa ssh-ed25519 ecdsa-sha2-nistp256 ecdsa-sha2-nistp384
                     ecdsa-sha2-nistp521 ssh-dss]
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

    fingerprint = calculate_fingerprint
    return unless fingerprint

    # Check if another key with the same fingerprint exists for this user
    if SshKey.where(user_id:, fingerprint:).where.not(id:).exists?
      errors.add(:public_key, "has already been added to your account")
      return
    end

    # Check if another key with the same fingerprint exists across all users
    return unless SshKey.where(fingerprint:).where.not(id:).exists?

    errors.add(:public_key, "is already in use by another user")
  end

  def self.ensure_unix_username!(user)
    username = UnixGroupManager.login_from_email(user.email)
    raise ProvisioningError, "Unable to derive Unix username for #{user.email}" unless username

    username
  end

  def self.sync_course_memberships!(user)
    user.course_user_data.where(instructor: true)
        .includes(:course).find_each do |cud|
      next if UnixGroupManager.update_course_staff_membership(cud.course, user, is_staff: true)

      raise ProvisioningError, "Failed to sync Unix group for #{cud.course.name}"
    end
  end

  private_class_method :ensure_unix_username!, :sync_course_memberships!
end
