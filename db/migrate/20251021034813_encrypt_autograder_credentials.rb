class EncryptAutograderCredentials < ActiveRecord::Migration[6.1]
  def up
    # Add encrypted columns for access keys
    add_column :autograders, :access_key_ciphertext, :text unless column_exists?(:autograders, :access_key_ciphertext)
    add_column :autograders, :access_key_id_ciphertext, :text unless column_exists?(:autograders, :access_key_id_ciphertext)

    # Migrate existing plaintext data to encrypted columns
    if column_exists?(:autograders, :access_key) || column_exists?(:autograders, :access_key_id)
      Autograder.reset_column_information
      Autograder.find_each do |autograder|
        if column_exists?(:autograders, :access_key) && autograder.read_attribute(:access_key).present?
          autograder.access_key = autograder.read_attribute(:access_key)
        end
        if column_exists?(:autograders, :access_key_id) && autograder.read_attribute(:access_key_id).present?
          autograder.access_key_id = autograder.read_attribute(:access_key_id)
        end
        autograder.save(validate: false) # Skip validation during migration
      end
    end

    # Remove plaintext columns after migration
    remove_column :autograders, :access_key if column_exists?(:autograders, :access_key)
    remove_column :autograders, :access_key_id if column_exists?(:autograders, :access_key_id)
  end

  def down
    # Add back plaintext columns
    add_column :autograders, :access_key, :string, default: "" unless column_exists?(:autograders, :access_key)
    add_column :autograders, :access_key_id, :string, default: "" unless column_exists?(:autograders, :access_key_id)

    # Migrate encrypted data back to plaintext columns
    Autograder.reset_column_information
    Autograder.find_each do |autograder|
      if autograder.access_key_ciphertext.present?
        autograder.update_column(:access_key, autograder.access_key || "")
      end
      if autograder.access_key_id_ciphertext.present?
        autograder.update_column(:access_key_id, autograder.access_key_id || "")
      end
    end

    # Remove encrypted columns
    remove_column :autograders, :access_key_ciphertext if column_exists?(:autograders, :access_key_ciphertext)
    remove_column :autograders, :access_key_id_ciphertext if column_exists?(:autograders, :access_key_id_ciphertext)
  end
end
