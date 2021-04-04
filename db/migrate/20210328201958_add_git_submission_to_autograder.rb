class AddGitSubmissionToAutograder < ActiveRecord::Migration[5.2]
  def change
    add_column :autograders, :git_enabled, :boolean, :default => false
    add_column :autograders, :git_assignment_name, :string
  end
end
