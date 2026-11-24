class AddIamUserCreatedAtToUsers < ActiveRecord::Migration[6.1]
  def change
    add_column :users, :iam_user_created_at, :datetime
  end
end
