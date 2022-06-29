class FixUserDefaults < ActiveRecord::Migration[4.2]
  def self.up
    change_column :users, :first_name, :string, :default=>""
    change_column :users, :last_name, :string, :default=>""
    change_column :users, :andrewID, :string, :null=>false
    change_column :users, :course_id, :integer, :null=>false
    change_column :users, :school, :string, :default=>""
    change_column :users, :major, :string, :default=>""
    change_column :users, :section, :string, :default=>""
    change_column :users, :grade_policy, :string, :default=>""
    change_column :users, :email, :string, :default=>""
    change_column :users, :administrator, :string, :default=>false

  end

  def self.down
  end
end
