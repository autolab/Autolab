class AddDisableonEndToCourses < ActiveRecord::Migration[6.1]
  def self.up
    add_column :courses, :disable_on_end, :boolean, default: false
  end

  def self.down
    remove_column :courses, :disable_on_end
  end
end
