class AddGradingDeadlineToAssessment < ActiveRecord::Migration
  def self.up
    add_column :assessments, :grading_deadline, :datetime
    change_column :assessments, :grading_deadline, :datetime, :null => false
    Assessment.find_each do |asmt|
      asmt.update_attribute(:grading_deadline, asmt.submit_until)
    end
  end

  def self.down
    remove_column :assessments, :grading_deadline
  end
end
