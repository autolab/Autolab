class CreateExtensions < ActiveRecord::Migration[4.2]
  def self.up
    create_table :extensions do |t|
      t.references :user
      t.references :assignment
      t.integer :days
    end
  end

  def self.down
    drop_table :extensions
  end
end
