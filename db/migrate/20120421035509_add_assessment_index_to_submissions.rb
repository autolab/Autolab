class AddAssessmentIndexToSubmissions < ActiveRecord::Migration
  def self.up
    add_index :submissions, :assessment_id
  end

  def self.down
    remove_index :submissions, assessment_id
  end
end
