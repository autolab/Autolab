class FixVisibleUntil < ActiveRecord::Migration[4.2]
  def self.up
    rename_column :assignments , :visable_until, :visible_at
  end

  def self.down
    rename_column :assignments, :visible_at, :visable_until
  end
end
