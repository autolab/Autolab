class AddCourseNumberToCourseUserData < ActiveRecord::Migration[6.0]
  def change
    add_column :course_user_data, :course_number, :string, default: ""
  end
end
