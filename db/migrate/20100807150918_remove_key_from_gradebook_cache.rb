class RemoveKeyFromGradebookCache < ActiveRecord::Migration[4.2]
  def self.up
    remove_index :gradebook_cache, :key
  end

  def self.down
    add_index :gradebook_cache, :key, **{:unique=>true}
  end
end
