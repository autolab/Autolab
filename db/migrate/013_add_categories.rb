class AddCategories < ActiveRecord::Migration[4.2]
  def self.up
    remove_column :assignments, :category
    add_column :assignments, :category_id, :integer
    create_table :assignment_categories do |t|
      t.string :name
      t.references :course
    end
    create_table :event_categories do |t|
      t.string :name
      t.references :course
    end
  end

  def self.down
    remove_column :assignments, :category_id
    add_column :assignments, :category, :string
    drop_table :assignment_categories
    drop_table :event_categories
  end
end
