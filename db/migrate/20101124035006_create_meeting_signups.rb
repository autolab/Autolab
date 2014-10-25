class CreateMeetingSignups < ActiveRecord::Migration
  def self.up
    create_table :meeting_signups do |t|
      t.references :meeting
      t.references :instructor
      t.references :user
      t.timestamp :time
      t.integer :length
      t.string :location
      t.string :notes

      t.timestamps
    end
  end

  def self.down
    drop_table :meeting_signups
  end
end
