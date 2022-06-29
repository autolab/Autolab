class AddCourseAssistantAttribute < ActiveRecord::Migration[4.2]
  def self.up
    add_column :users, :course_assistant, :boolean, :default=>false
  end

  def self.down
    remove_column :users, :course_assistant
  end
end
