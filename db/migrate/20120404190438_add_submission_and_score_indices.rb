class AddSubmissionAndScoreIndices < ActiveRecord::Migration
  def self.up
    add_index :submissions, :user_id
    add_index :scores, :submission_id
  end

  def self.down
    remove_index :submissions, :user_id
    remove_index :scores, :submission_id
  end
end
