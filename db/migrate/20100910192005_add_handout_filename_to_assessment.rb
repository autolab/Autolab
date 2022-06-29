class AddHandoutFilenameToAssessment < ActiveRecord::Migration[4.2]
  def self.up
    add_column :assessments, :handout_filename, :string
  end

  def self.down
    remove_column :assessments, :handout_filename
  end
end
