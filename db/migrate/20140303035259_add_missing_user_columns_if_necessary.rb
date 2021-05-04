# frozen_string_literal: true

class AddMissingUserColumnsIfNecessary < ActiveRecord::Migration[4.2]
  def up
    add_column :users, :confirmation_token, :string unless column_exists?(:users,
                                                                          :confirmation_token)
    add_column :users, :confirmed_at, :datetime unless column_exists?(:users, :confirmed_at)
    unless column_exists?(:users, :confirmation_sent_at)
      add_column :users, :confirmation_sent_at, :datetime
    end
    add_column :users, :unconfirmed_email, :string unless column_exists?(:users, :unconfirmed_email)
    User.find_each do |u|
      u.confirm! unless u.confirmed?
    end
  end

  def down
    remove_column :users, :confirmation_token if column_exists?(:users, :confirmation_token)
    remove_column :users, :confirmed_at if column_exists?(:users, :confirmed_at)
    remove_column :users, :confirmation_sent_at if column_exists?(:users, :confirmation_sent_at)
    remove_column :users, :unconfirmed_email if column_exists?(:users, :unconfirmed_email)
  end
end
