class AddHandoutFilenameToAssessment < ActiveRecord::Migration
  def self.up
    add_column :assessments, :handout_filename, :string
  end

  def self.down
    remove_column :assessments, :handout_filename
  end
end
