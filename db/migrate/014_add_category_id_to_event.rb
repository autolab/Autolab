class AddCategoryIdToEvent < ActiveRecord::Migration[4.2]
  def self.up
    add_column :events, :category_id, :integer
  end

  def self.down
    remove_column :events, :category_id
  end
end
