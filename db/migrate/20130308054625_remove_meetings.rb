class RemoveMeetings < ActiveRecord::Migration[4.2]
  def self.up
    drop_table :meeting_signups
    drop_table :meetings
  end

  def self.down
    create_table "meetings", :force => true do |t|
      t.integer  "course_id"
      t.string   "name"
      t.boolean  "open"
      t.integer  "cancel_time"
      t.datetime "created_at"
      t.datetime "updated_at"
      t.integer  "preregistry_time"
      t.boolean  "grader_visible",   :default => true
    end

    create_table "meeting_signups", :force => true do |t|
      t.integer  "meeting_id"
      t.integer  "instructor_id"
      t.integer  "user_id"
      t.datetime "time"
      t.integer  "length"
      t.string   "location"
      t.string   "notes"
      t.datetime "created_at"
      t.datetime "updated_at"
    end
  end
end
