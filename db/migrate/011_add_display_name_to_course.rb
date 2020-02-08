class AddDisplayNameToCourse < ActiveRecord::Migration[4.2]
  def self.up
    add_column :courses, :display_name, :string
  end

  def self.down
    remove_column :courses, :display_name
  end
end
