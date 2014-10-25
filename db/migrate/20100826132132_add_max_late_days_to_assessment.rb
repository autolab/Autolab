class AddMaxLateDaysToAssessment < ActiveRecord::Migration
  def self.up
    add_column :assessments, :max_grace_days, :integer 
  end

  def self.down
    remove_column :assessments, :max_grace_days
  end
end
