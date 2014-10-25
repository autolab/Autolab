class AddDisableHandinToAssessment < ActiveRecord::Migration
  def self.up
    add_column :assessments, :disable_handins, :boolean
  end

  def self.down
    remove_column :assessments, :disable_handins
  end
end
