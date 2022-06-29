class RenameWriteupHandoutFilename < ActiveRecord::Migration[4.2]
  def change
    rename_column :assessments, :writeup_filename, :writeup
    rename_column :assessments, :handout_filename, :handout
  end
end
