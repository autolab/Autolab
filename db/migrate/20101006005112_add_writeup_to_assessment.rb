class AddWriteupToAssessment < ActiveRecord::Migration[4.2]
  def self.up
    add_column :assessments, :writeup_filename, :string
  end

  def self.down
    remove_column :assessments, :writeup_filename
  end
end
