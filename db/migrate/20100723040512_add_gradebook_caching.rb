class AddGradebookCaching < ActiveRecord::Migration[4.2]
  def self.up
    create_table :gradebook_cache, :id=>false do |t|
      t.string :key
      t.string :value
    end
    add_index :gradebook_cache, :key, **{:unique=>true}

    create_table :gradebook_cache_averages, :id=>false do |t|
      t.string :field
      t.integer :field_id
      t.integer :user_id
      t.float :average
      t.integer :expired
    end
    #add_index :gradebook_cache_averages, 
    #      [:field,:field_id,:user_id],
    #      {:unique=>true}

    create_table :gradebook_cache_statistics, :id=>false do |t|
      t.string :field
      t.integer :field_id
      t.string :name
      t.float :value
      t.integer :expired
    end
    #add_index :gradebook_cache_statistics,
    #      [:field,:field_id,:name],
    #      {:unique=>true}
  end

  def self.down
    drop_table :gradebook_cache
    drop_table :gradebook_cache_averages
    drop_table :gradebook_cache_statistics
  end
end
