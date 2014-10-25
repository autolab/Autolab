class AddAllowUnofficialSubmissionsToAssessment < ActiveRecord::Migration
  def self.up
    add_column :assessments, :allow_unofficial, :boolean
  end

  def self.down
    remove_column :assessments, :allow_unofficial
  end
end
