#I don't know what I was smoking that made me make administrator a string.. it
#should be boolean

class FixTypeOfAdministrator < ActiveRecord::Migration[4.2]
  def self.up
    change_column :users, :administrator, :boolean, :default=>false
  end

  def self.down
    change_columns :user, :administrator, :string
  end
end
