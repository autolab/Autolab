class AddGraderOptionToMeetings < ActiveRecord::Migration
  def self.up
    add_column :meetings, :grader_visible, :boolean, :default => 1
  end

  def self.down
    remove_column :meetings, :grader_visible
  end
end
