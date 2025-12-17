class AddEc2SshFieldsToAutograders < ActiveRecord::Migration[6.1]
  def change
    add_column :autograders, :instance_type, :string, default: ""
    add_column :autograders, :access_key, :string, default: ""
    add_column :autograders, :access_key_id, :string, default: ""
  end
end
