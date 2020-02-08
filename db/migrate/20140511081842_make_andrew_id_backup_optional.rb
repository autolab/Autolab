class MakeAndrewIdBackupOptional < ActiveRecord::Migration[4.2]
  def change
    change_column :course_user_data, :andrewID_backup, :string, :null => true
  end
end
