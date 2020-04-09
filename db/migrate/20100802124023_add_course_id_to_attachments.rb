class AddCourseIdToAttachments < ActiveRecord::Migration[4.2]
  def self.up
    add_column :attachments, :course_id, :integer
  end

  def self.down
    remove_column :attachments, :course_id
  end
end
