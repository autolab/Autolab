class CreateSubmission < ActiveRecord::Migration
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
