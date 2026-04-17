class AddUnixUserToUsers < ActiveRecord::Migration[6.1]
  def change
    add_column :users, :unix_user, :string
    add_index :users, :unix_user, unique: true
  end
end
