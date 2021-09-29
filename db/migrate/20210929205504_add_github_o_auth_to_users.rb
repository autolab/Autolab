class AddGithubOAuthToUsers < ActiveRecord::Migration[5.2]
  def change
    add_column :users, :oauth_state, :string
    add_column :users, :github_access_token, :string
  end
end
