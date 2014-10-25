class MakeAndrewIdBackupOptional < ActiveRecord::Migration
  def change
    change_column :course_user_data, :andrewID_backup, :string, :null => true
  end
end
