class AddAccessKeyIdAndAccessKeyToCourseUserData < ActiveRecord::Migration
  def change
    add_column :course_user_data, :access_key_id, :string
    add_column :course_user_data, :access_key, :string
  end
end
