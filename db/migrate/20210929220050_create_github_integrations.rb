class CreateGithubIntegrations < ActiveRecord::Migration[5.2]
  def change
    create_table :github_integrations do |t|
      t.string :oauth_state
      t.text :access_token_ciphertext
      t.references :user, foreign_key: true, type: :integer, index: { unique: true }
      
      t.timestamps
    end
    add_index :github_integrations, :oauth_state, unique: true
  end
end
