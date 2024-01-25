class AddTweakTypeToUsers < ActiveRecord::Migration[4.2]
  def self.up
  add_column :users, :absolute_tweak, :boolean, **{ :default => true, :null => false }

  User.where("tweak <= 1 and tweak >= -1").each do |u|
    u.absolute_tweak = false
    u.save(false)
  end

  end

  def self.down
  remove_column :users, :absolute_tweak
  end
end
