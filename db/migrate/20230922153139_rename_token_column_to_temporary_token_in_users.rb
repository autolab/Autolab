class RenameTokenColumnToTemporaryTokenInUsers < ActiveRecord::Migration[6.0]
  def change
    rename_column :users, :token, :temporary_token
  end
end
