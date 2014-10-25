class AddGradeTypeToAssessmentUserData < ActiveRecord::Migration
  def self.up
    add_column :assessment_user_data, :grade_type, :integer, :null => false, :default => 0
  end

  def self.down
    remove_column :assessment_user_data, :grade_type
  end
end
