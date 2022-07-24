class AddGithubSubmissionEnabledToAssessments < ActiveRecord::Migration[5.2]
  def change
    add_column :assessments, :github_submission_enabled, :boolean, default: true
  end
end
