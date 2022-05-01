class AddDisableHandinToAssessment < ActiveRecord::Migration[4.2]
  def self.up
    add_column :assessments, :disable_handins, :boolean
  end

  def self.down
    remove_column :assessments, :disable_handins
  end
end
