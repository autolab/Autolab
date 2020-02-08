class AddEventShit < ActiveRecord::Migration[4.2]
  def self.up
    create_table :event_schemas do |t|  
      t.references :category
      t.references :course
      t.string :title, :null=>false
      t.boolean :monday, :default=>false
      t.boolean :tuesday, :default=>false
      t.boolean :wednesday, :default=>false
      t.boolean :thursday, :default=>false
      t.boolean :friday, :default=>false
      t.boolean :saturday, :default=>false
      t.boolean :sunday, :default=>false
    end
  
    create_table :event_specifications do |t|
      t.references :event_schema
      t.references :instructor
      t.time :start_time, :null=>false
      t.time :end_time, :null=>false
      t.string :location, :null=>false
      t.string :title, :default=>""
    end
  
    create_table :event_exceptions do |t|
      t.references :event_specification 
      t.string :action, :null=>false
      t.references :instructor
      t.timestamp :start_time, :null=>false
      t.timestamp :end_time
      t.string :location
      t.string :title
    end

    create_table :event_information do |t|
      t.references :event_schema, :null=>false
      t.date :date, :null=>false
      t.references :acting_instructor
      t.text :description
      t.string :title
    end

    add_column :courses, :start_date, :date
    add_column :courses, :end_date, :date
  end

  def self.down
    drop_table :event_schemas
    drop_table :event_specifications
    drop_table :event_exceptions
    drop_table :event_information
  end
end
