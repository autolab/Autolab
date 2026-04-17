class AddEc2SshFieldsToAutograders < ActiveRecord::Migration[6.1]
  def up
    add_column :autograders, :instance_type, :string, default: "" unless column_exists?(:autograders, :instance_type)
    add_column :autograders, :access_key_ciphertext, :text unless column_exists?(:autograders, :access_key_ciphertext)
    add_column :autograders, :access_key_id_ciphertext, :text unless column_exists?(:autograders, :access_key_id_ciphertext)

    remove_column :autograders, :access_key if column_exists?(:autograders, :access_key)
    remove_column :autograders, :access_key_id if column_exists?(:autograders, :access_key_id)
  end

  def down
    add_column :autograders, :access_key, :string, default: "" unless column_exists?(:autograders, :access_key)
    add_column :autograders, :access_key_id, :string, default: "" unless column_exists?(:autograders, :access_key_id)

    remove_column :autograders, :access_key_ciphertext if column_exists?(:autograders, :access_key_ciphertext)
    remove_column :autograders, :access_key_id_ciphertext if column_exists?(:autograders, :access_key_id_ciphertext)
    remove_column :autograders, :instance_type if column_exists?(:autograders, :instance_type)
  end
end
