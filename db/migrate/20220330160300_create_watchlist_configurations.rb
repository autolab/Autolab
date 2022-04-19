class CreateWatchlistConfigurations < ActiveRecord::Migration[6.0]
  def up
    create_table :watchlist_configurations do |t|
      t.json :category_allowlist
      t.json :assessment_allowlist
      t.references :course
      
      t.timestamps
    end
  end

  def down
    drop_table :watchlist_configurations
  end
end
