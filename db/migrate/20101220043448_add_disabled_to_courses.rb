class AddDisabledToCourses < ActiveRecord::Migration
  def self.up
    add_column :courses, :disabled, :boolean, {:default=>false}
  end

  def self.down
    remove_column :courses, :disabled
  end
end
