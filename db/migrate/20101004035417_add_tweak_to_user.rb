class AddTweakToUser < ActiveRecord::Migration
  def self.up
    add_column :users, :tweak, :float, :default=>0, :null=>false
  end

  def self.down
    remove_column :users, :tweak
  end
end
