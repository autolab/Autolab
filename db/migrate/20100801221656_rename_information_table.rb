class RenameInformationTable < ActiveRecord::Migration
  def self.up
    rename_table :event_information, :event_informations
  end

  def self.down
  rename_table :event_informations, :event_information
  end
end
