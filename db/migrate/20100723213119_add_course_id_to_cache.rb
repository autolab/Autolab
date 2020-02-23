class AddCourseIdToCache < ActiveRecord::Migration[4.2]
  def self.up
    add_column :gradebook_cache, :course_id, :integer
  end

  def self.down
    remove_colunn :gradebook_cache, :course_id
  end
end
