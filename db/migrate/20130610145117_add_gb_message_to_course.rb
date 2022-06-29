class AddGbMessageToCourse < ActiveRecord::Migration[4.2]
  def self.up
    add_column :courses, :gb_message, :text
  end

  def self.down
    remove_column :courses, :gb_message
  end
end
