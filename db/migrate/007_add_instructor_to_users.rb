class AddInstructorToUsers < ActiveRecord::Migration[4.2]
  def self.up
    add_column :users, :instructor, :boolean, **{:default=>false}
  end

  def self.down
    remove_column :users, :instructor
  end
end
