class AddPlatformToLtiCourseData < ActiveRecord::Migration[6.0]
  def change
    add_column :lti_course_data, :platform, :string
  end
end
