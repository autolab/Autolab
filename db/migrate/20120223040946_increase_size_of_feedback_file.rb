class IncreaseSizeOfFeedbackFile < ActiveRecord::Migration[4.2]
  def self.up
    change_column :scores, :feedback_file, :longblob, :null=>true
  end

  def self.down
  end
end
