class RemoveUnsusedEvents < ActiveRecord::Migration[4.2]
  def self.up
    drop_table :event_categories
    drop_table :event_exceptions
    drop_table :event_informations
    drop_table :event_schemas
    drop_table :event_specifications
    drop_table :events
  end

  def self.down
    create_table "event_categories" do |t|
      t.string  "name"
      t.integer "course_id"
    end

    create_table "event_exceptions" do |t|
      t.integer  "event_specification_id"
      t.string   "action",                 :null => false
      t.integer  "instructor_id"
      t.datetime "start_time",             :null => false
      t.datetime "end_time"
      t.string   "location"
      t.string   "title"
      t.datetime "original_start_date"
    end

    create_table "event_informations" do |t|
      t.integer "event_schema_id",      :null => false
      t.date    "date",                 :null => false
      t.integer "acting_instructor_id"
      t.text    "description"
      t.string  "title"
    end

    create_table "event_schemas" do |t|
      t.integer "category_id"
      t.integer "course_id"
      t.string  "title",                          :null => false
      t.boolean "monday",      :default => false
      t.boolean "tuesday",     :default => false
      t.boolean "wednesday",   :default => false
      t.boolean "thursday",    :default => false
      t.boolean "friday",      :default => false
      t.boolean "saturday",    :default => false
      t.boolean "sunday",      :default => false
    end

    create_table "event_specifications" do |t|
      t.integer "event_schema_id"
      t.integer "instructor_id"
      t.time    "start_time",                      :null => false
      t.time    "end_time",                        :null => false
      t.string  "location",                        :null => false
      t.string  "title",           :default => ""
    end

    create_table "events" do |t|
      t.string   "name"
      t.text     "description"
      t.datetime "date"
      t.boolean  "private"
      t.integer  "course_id"
      t.datetime "created_at"
      t.datetime "updated_at"
      t.integer  "category_id"
    end
  end
end
