class MakeTweakOldOptional < ActiveRecord::Migration[4.2]
  def change
    change_column :course_user_data, :tweak_old, :float, :null => true
    change_column :course_user_data, :absolute_tweak, :boolean, :null => true
  end
end
