class AddPerAssessmentLatePenalty < ActiveRecord::Migration[4.2]
  def self.up
    add_column :assessments, :late_penalty, :float
  end

  def self.down
    remove_column :assessments, :late_penalty
  end
end
