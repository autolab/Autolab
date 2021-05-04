# frozen_string_literal: true

class AddScoresSubmissionProblemUniqueKey < ActiveRecord::Migration[4.2]
  def self.up
    add_index "scores", %w[problem_id submission_id], name: "problem_submission_unique",
                                                      unique: true
  end

  def down; end
end
