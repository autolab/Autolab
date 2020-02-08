class AddAllowUnofficialSubmissionsToAssessment < ActiveRecord::Migration[4.2]
  def self.up
    add_column :assessments, :allow_unofficial, :boolean
  end

  def self.down
    remove_column :assessments, :allow_unofficial
  end
end
