class RemoveGradingDeadlineFromAssessments < ActiveRecord::Migration[6.0]
  def up
    remove_column :assessments, :grading_deadline if column_exists?(:assessments, :grading_deadline)
  end
  def down
    unless column_exists?(:assessments, :grading_deadline)
      add_column :assessments, :grading_deadline, :datetime, null: false
      Assessment.find_each do |asmt|
        asmt.update_attribute(:grading_deadline, asmt.end_at)
      end
    end
  end
end
