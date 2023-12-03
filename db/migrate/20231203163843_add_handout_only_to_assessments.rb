class AddHandoutOnlyToAssessments < ActiveRecord::Migration[6.0]
  def change
    add_column :assessments, :handout_only, :boolean, default: false
  end
end
