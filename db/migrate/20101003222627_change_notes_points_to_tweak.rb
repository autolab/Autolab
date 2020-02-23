class ChangeNotesPointsToTweak < ActiveRecord::Migration[4.2]
  def self.up
    rename_column :submissions, :notes_points, :tweak
    change_column :submissions, :tweak, :float, :default=>0
  end

  def self.down
    rename_column :submissions, :tweak, :notes_points
  end
end
