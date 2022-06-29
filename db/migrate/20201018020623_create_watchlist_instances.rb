class CreateWatchlistInstances < ActiveRecord::Migration[5.2]
  def up
    create_table :watchlist_instances do |t|
      t.references :course_user_datum
      t.references :course
      t.references :risk_condition
      t.integer :status, :default => 0 # 0 stands for status new
      t.boolean :archived, :default => false
      t.timestamps
    end
  end

  def down
    drop_table :watchlist_instances
  end
end
