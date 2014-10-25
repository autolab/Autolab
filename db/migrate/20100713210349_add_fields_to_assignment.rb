class AddFieldsToAssignment < ActiveRecord::Migration
  def self.up
    add_column :assignments, :handin_filename, :string
    add_column :assignments, :handin_directory, :string
  end

  def self.down
    remove_column :assignments, :handin_filename
    remove_column :assignments, :handin_directory
  end
end
