class AddDisplayNameToCourse < ActiveRecord::Migration
  def self.up
    add_column :courses, :display_name, :string
  end

  def self.down
    remove_column :courses, :display_name
  end
end
