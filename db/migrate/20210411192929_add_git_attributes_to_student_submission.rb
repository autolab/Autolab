class AddGitAttributesToStudentSubmission < ActiveRecord::Migration[5.2]
  def change
    add_column :submissions, :git_student_username, :string
    add_column :submissions, :git_commit_hash, :string
  end
end
