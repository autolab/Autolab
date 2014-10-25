class IncreaseSizeOfFeedbackFile < ActiveRecord::Migration
  def self.up
    change_column :scores, :feedback_file, :longblob, :null=>true
  end

  def self.down
  end
end
