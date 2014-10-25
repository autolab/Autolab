class CreateScheduler < ActiveRecord::Migration
  def self.up
    create_table :scheduler do |t|
      t.string :action
      t.timestamp :next
      t.integer :interval
      t.integer :course_id

      t.timestamps
    end
  end

  def self.down
    drop_table :scheduler
  end
end
