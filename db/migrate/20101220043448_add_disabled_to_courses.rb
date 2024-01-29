class AddDisabledToCourses < ActiveRecord::Migration[4.2]
  def self.up
    add_column :courses, :disabled, :boolean, **{:default=>false}
  end

  def self.down
    remove_column :courses, :disabled
  end
end
