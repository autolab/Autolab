class AddCgdubDependenciesUpdatedAtToCourse < ActiveRecord::Migration[4.2]
  def self.up
    # default to now for easy prepopulation
    add_column :courses, :cgdub_dependencies_updated_at, :datetime, :default => Time.now

    # default really shouldn't be *now*; will be taken care of in before_create going forward
    change_column :courses, :cgdub_dependencies_updated_at, :datetime, :default => nil
  end

  def self.down
    remove_column :courses, :cgdub_dependencies_updated_at
  end
end
