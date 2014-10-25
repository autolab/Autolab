class RemoveKeyFromGradebookCache < ActiveRecord::Migration
  def self.up
    remove_index :gradebook_cache, :key
  end

  def self.down
    add_index :gradebook_cache, :key, {:unique=>true}
  end
end
