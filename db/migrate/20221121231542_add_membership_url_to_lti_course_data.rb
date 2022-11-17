class AddMembershipUrlToLtiCourseData < ActiveRecord::Migration[6.0]
  def change
    add_column :lti_course_data, :membership_url, :string
  end
end
