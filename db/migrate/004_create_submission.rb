class CreateSubmission < ActiveRecord::Migration[4.2]
  def self.up
    create_table :submissions do |t|
      t.integer :version
      t.references :user
      t.references :assignment
      t.string :filename
      t.timestamps
    end
  end

  def self.down
    drop_table :submissions
  end
end
