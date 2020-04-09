class ScoreboardSetupsToScoreboard < ActiveRecord::Migration[4.2]
  def change
    rename_table :scoreboard_setups, :scoreboards
    change_column :scoreboards, :banner, :text, limit: 65535
    change_column :scoreboards, :colspec, :text, limit: 65535
    rename_column :assessments, :has_scoreboard, :has_scoreboard_old
  end
end
