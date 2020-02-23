class RenameAssessmentDates < ActiveRecord::Migration[4.2]
  def change
    rename_column :assessments, :due_date, :due_at
    rename_column :assessments, :start_date, :start_at
    rename_column :assessments, :submit_until, :end_at
  end
end
