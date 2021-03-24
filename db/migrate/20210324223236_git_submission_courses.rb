class GitSubmissionCourses < ActiveRecord::Migration[5.2]
  def change
    add_column :courses, :git_access_key, :string
    add_column :courses, :classroom_name, :string
  end
end
