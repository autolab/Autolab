class CreateEvents < ActiveRecord::Migration[4.2]
  def self.up
    create_table :events do |t|
      t.string :name
      t.text :description
      t.timestamp :date
      t.boolean :private
      t.references :course

      t.timestamps
    end
  end

  def self.down
    drop_table :events
  end
end
