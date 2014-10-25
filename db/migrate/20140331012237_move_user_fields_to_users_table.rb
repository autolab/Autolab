class MoveUserFieldsToUsersTable < ActiveRecord::Migration
  def change
    change_table :users do |u|
      u.string :school
      u.string :major
      u.string :year
    end
  end
end
