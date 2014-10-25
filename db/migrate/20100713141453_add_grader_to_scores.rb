class AddGraderToScores < ActiveRecord::Migration
  def self.up
    add_column :scores, :grader_id, :integer
  end

  def self.down
    remove_column :scores, :grader_id
  end
end
