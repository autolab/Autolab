class AddExceptionOldStartTime < ActiveRecord::Migration
  def self.up
    add_column :event_exceptions, :original_start_date, :timestamp
  end

  def self.down
    remove_column :event_exceptions, :original_start_date
  end
end
