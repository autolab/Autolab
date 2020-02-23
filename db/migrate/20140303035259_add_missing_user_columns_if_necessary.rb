class AddMissingUserColumnsIfNecessary < ActiveRecord::Migration[4.2]
  def up
    if (!column_exists?(:users, :confirmation_token))
      add_column :users, :confirmation_token, :string
    end
    if (!column_exists?(:users, :confirmed_at))
      add_column :users, :confirmed_at, :datetime
    end
    if (!column_exists?(:users, :confirmation_sent_at))
      add_column :users, :confirmation_sent_at, :datetime
    end
    if (!column_exists?(:users, :unconfirmed_email))
      add_column :users, :unconfirmed_email, :string
    end
    User.find_each do |u|
      if (!u.confirmed?) 
        u.confirm!
      end
    end
  end

  def down
    if (column_exists?(:users, :confirmation_token))
      remove_column :users, :confirmation_token
    end
    if (column_exists?(:users, :confirmed_at))
      remove_column :users, :confirmed_at
    end
    if (column_exists?(:users, :confirmation_sent_at))
      remove_column :users, :confirmation_sent_at
    end
    if (column_exists?(:users, :unconfirmed_email))
      remove_column :users, :unconfirmed_email
    end
  end
end
