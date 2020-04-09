class AddFeedbackFileToScore < ActiveRecord::Migration[4.2]
  def self.up
    add_column :scores, :feedback_file, :binary, :null=>true
    add_column :scores, :feedback_file_type, :string, :null=>true
    add_column :scores, :feedback_file_name, :string, :null=>true
  end

  def self.down
    remove_column :scores, :feedback_file
    remove_column :scores, :feedback_file_type
    remove_column :scores, :feedback_file_name
  end
end
