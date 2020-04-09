class CreateScores < ActiveRecord::Migration[4.2]
  def self.up
    create_table :scores do |t|
      t.references :submission
      t.float :score
      t.string :feedback
      t.references :problem

      t.timestamps
    end
  end

  def self.down
    drop_table :scores
  end
end
