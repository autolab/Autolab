# frozen_string_literal: true

class AddAssessmentIndexToSubmissions < ActiveRecord::Migration[4.2]
  def self.up
    add_index :submissions, :assessment_id
  end

  def self.down
    remove_index :submissions, assessment_id
  end
end
