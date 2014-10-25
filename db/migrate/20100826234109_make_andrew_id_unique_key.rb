class MakeAndrewIdUniqueKey < ActiveRecord::Migration
  def self.up
    add_index :users, [:andrewID,:course_id], {:unique=>true,:name=>"users_andrewID_index"}
  end

  def self.down
    remove_index :users, "users_andrewID_index"
  end
end
