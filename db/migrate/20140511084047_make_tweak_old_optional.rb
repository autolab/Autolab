class MakeTweakOldOptional < ActiveRecord::Migration
  def change
    change_column :course_user_data, :tweak_old, :float, :null => true
    change_column :course_user_data, :absolute_tweak, :boolean, :null => true
  end
end
