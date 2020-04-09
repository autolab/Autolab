class AddCourseId < ActiveRecord::Migration[4.2]
  def self.up
    add_column :assignments, :course_id , :integer
  end

  def self.down
    remove_column :assignments, :course
  end
end
