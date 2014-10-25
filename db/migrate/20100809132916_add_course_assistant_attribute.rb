class AddCourseAssistantAttribute < ActiveRecord::Migration
  def self.up
    add_column :users, :course_assistant, :boolean, :default=>false
  end

  def self.down
    remove_column :users, :course_assistant
  end
end
