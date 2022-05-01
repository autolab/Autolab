class RemoveUserAndrewIdIndex < ActiveRecord::Migration[4.2]
  def up
    remove_index "course_user_data",  name: "users_andrewID_index"
  end
  
  def down
    add_index "course_user_data", ["andrewID_backup", "course_id"], name: "users_andrewID_index", unique: true, using: :btree
  end
  
end
