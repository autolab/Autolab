class AddAllowCaToWatchlistConfigurations < ActiveRecord::Migration[6.0]
  def up
    add_column :watchlist_configurations, :allow_ca, :boolean, default: false
  end

  def down
    remove_column :watchlist_configurations, :allow_ca
  end
end
