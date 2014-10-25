class AddInfiniteToExtension < ActiveRecord::Migration
  def self.up
    add_column :extensions, :infinite, :boolean,
      :default => false, :null => false
  end

  def self.down
    remove_column :extensions, :infinite
  end
end
