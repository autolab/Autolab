class AddNicknameToUsers < ActiveRecord::Migration
  def self.up
    add_column :users, :nickname, :string
  end

  def self.down
    remove_column :users, :nickname, :string
  end
end
