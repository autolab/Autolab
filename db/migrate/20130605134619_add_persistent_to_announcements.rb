class AddPersistentToAnnouncements < ActiveRecord::Migration
  def self.up
    add_column :announcements, :persistent, :boolean, :null => false, :default => false
  end

  def self.down
    remove_column :announcements, :persistent
  end
end
