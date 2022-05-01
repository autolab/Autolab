class ChangeAssignmentToAssessment < ActiveRecord::Migration[4.2]
  def self.up
    rename_table :assignments, :assessments
    rename_table :assignment_categories, :assessment_categories
    rename_column :extensions, :assignment_id, :assessment_id
    rename_column :problems, :assignment_id, :assessment_id
    rename_column :submissions, :assignment_id, :assessment_id
  end

  def self.down
    rename_table :assessments, :assignments
    rename_table :assessment_categories, :assignment_categories
    rename_column :extensions, :assessment_id, :assignment_id
    rename_column :problems, :assessment_id, :assignment_id
    rename_column :submissions, :assessment_id, :assignment_id
  end
end
