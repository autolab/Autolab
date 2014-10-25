class DroppedDefaultFalse < ActiveRecord::Migration
  def self.up
  change_column :users, :dropped, :boolean, :default=>false
  end

  def self.down
  end
end
