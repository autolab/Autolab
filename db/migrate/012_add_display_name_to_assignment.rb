class AddDisplayNameToAssignment < ActiveRecord::Migration[4.2]
  def self.up
    add_column :assignments, :display_name, :string
  end

  def self.down
    remove_column :assignments, :display_name
  end
end
