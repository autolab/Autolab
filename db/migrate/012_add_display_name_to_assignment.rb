class AddDisplayNameToAssignment < ActiveRecord::Migration
  def self.up
    add_column :assignments, :display_name, :string
  end

  def self.down
    remove_column :assignments, :display_name
  end
end
