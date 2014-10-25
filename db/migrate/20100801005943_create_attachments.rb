class CreateAttachments < ActiveRecord::Migration
  def self.up
    create_table :attachments do |t|
      t.string :filename
      t.string :mime_type
      t.boolean :released
      t.string :type
      t.integer :foreign_key
      t.string :name

      t.timestamps
    end
  end

  def self.down
    drop_table :attachments
  end
end
