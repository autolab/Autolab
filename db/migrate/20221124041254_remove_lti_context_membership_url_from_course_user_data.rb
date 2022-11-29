class RemoveLtiContextMembershipUrlFromCourseUserData < ActiveRecord::Migration[6.0]
  def change
    remove_column :course_user_data, :lti_context_membership_url, :string
  end
end
