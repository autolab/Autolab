class AddScoresSubmissionProblemUniqueKey < ActiveRecord::Migration[4.2]
  def self.up
    add_index "scores",["problem_id","submission_id"],:name=>"problem_submission_unique",:unique=>true
  end

  def down

  end
end
