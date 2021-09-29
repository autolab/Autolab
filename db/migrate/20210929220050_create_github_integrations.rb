class CreateGithubIntegrations < ActiveRecord::Migration[5.2]
  def change
    create_table :github_integrations do |t|
      t.string :oauth_state
      t.string :access_token
      t.references :user, foreign_key: true

      t.timestamps
    end
    add_index :github_integrations, :oauth_state, unique: true
  end
end
