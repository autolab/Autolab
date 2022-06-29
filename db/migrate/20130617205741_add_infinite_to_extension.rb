class AddInfiniteToExtension < ActiveRecord::Migration[4.2]
  def self.up
    add_column :extensions, :infinite, :boolean,
      :default => false, :null => false
  end

  def self.down
    remove_column :extensions, :infinite
  end
end
