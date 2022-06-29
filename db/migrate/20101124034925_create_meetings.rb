class CreateMeetings < ActiveRecord::Migration[4.2]
  def self.up
    create_table :meetings do |t|
      t.references :course
      t.string :name
      t.boolean :open
      t.integer :cancel_time
      t.timestamps
    end
  end

  def self.down
    drop_table :meetings
  end
end
