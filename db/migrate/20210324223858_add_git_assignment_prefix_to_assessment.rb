class AddGitAssignmentPrefixToAssessment < ActiveRecord::Migration[5.2]
  def change
    add_column :assessments, :git_assignment_prefix, :string
  end
end
