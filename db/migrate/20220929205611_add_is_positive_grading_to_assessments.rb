class AddIsPositiveGradingToAssessments < ActiveRecord::Migration[6.0]
  def up
    add_column :assessments, :is_positive_grading, :boolean, default: false
  end

  def down
    remove_column :assessments, :is_positive_grading
  end
end
