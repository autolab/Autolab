class AddGraderToScores < ActiveRecord::Migration[4.2]
  def self.up
    add_column :scores, :grader_id, :integer
  end

  def self.down
    remove_column :scores, :grader_id
  end
end
