class AddAutoSyncAndDropMissingStudentsToLtiCourseData < ActiveRecord::Migration[6.0]
  def change
    add_column :lti_course_data, :auto_sync, :boolean, default: false
    add_column :lti_course_data, :drop_missing_students, :boolean, default: false
  end
end
