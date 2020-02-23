class CreateAnnotations < ActiveRecord::Migration[4.2]
  def self.up
    create_table :annotations do |t|
      t.integer :submission_id
      t.string :filename
      t.integer :position
      
      t.integer :line
      t.string :text

      t.timestamps
    end
  end

  def self.down
    drop_table :annotations
  end
end
