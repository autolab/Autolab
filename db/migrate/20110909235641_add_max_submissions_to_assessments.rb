class AddMaxSubmissionsToAssessments < ActiveRecord::Migration
  def self.up
    add_column :assessments, :max_submissions, :integer, :default=>-1
  end

  def self.down
    remove_column :assessments, :max_submissions
  end
end
