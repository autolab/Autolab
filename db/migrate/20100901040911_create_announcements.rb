class CreateAnnouncements < ActiveRecord::Migration[4.2]
  def self.up
    create_table :announcements do |t|
      t.string :title
      t.text :description
      t.timestamp :start_date
      t.timestamp :end_date
      t.references :user
      t.references :course

      t.timestamps
    end
  end

  def self.down
    drop_table :announcements
  end
end
