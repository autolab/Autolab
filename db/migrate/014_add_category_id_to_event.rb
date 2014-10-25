class AddCategoryIdToEvent < ActiveRecord::Migration
  def self.up
    add_column :events, :category_id, :integer
  end

  def self.down
    remove_column :events, :category_id
  end
end
