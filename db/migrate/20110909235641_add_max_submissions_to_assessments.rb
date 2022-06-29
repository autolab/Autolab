class AddMaxSubmissionsToAssessments < ActiveRecord::Migration[4.2]
  def self.up
    add_column :assessments, :max_submissions, :integer, :default=>-1
  end

  def self.down
    remove_column :assessments, :max_submissions
  end
end
