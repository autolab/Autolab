class DroppedDefaultFalse < ActiveRecord::Migration[4.2]
  def self.up
  change_column :users, :dropped, :boolean, :default=>false
  end

  def self.down
  end
end
