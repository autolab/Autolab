class CreateAssignments < ActiveRecord::Migration[4.2]
  def self.up
    create_table :assignments do |t|
      t.timestamp :due_date
      t.timestamp :submit_until
      t.timestamp :visable_until
      t.timestamp :available_date
      t.string :name
      t.text :description
      t.timestamps
    end
  end

  def self.down
    drop_table :assignments
  end
end
