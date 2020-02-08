class RenameInformationTable < ActiveRecord::Migration[4.2]
  def self.up
    rename_table :event_information, :event_informations
  end

  def self.down
  rename_table :event_informations, :event_information
  end
end
