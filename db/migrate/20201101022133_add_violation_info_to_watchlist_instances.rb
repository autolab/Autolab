class AddViolationInfoToWatchlistInstances < ActiveRecord::Migration[5.2]
  def change
    add_column :watchlist_instances, :violation_info, :json
  end
end
