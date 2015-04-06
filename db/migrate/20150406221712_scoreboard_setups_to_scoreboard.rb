class ScoreboardSetupsToScoreboard < ActiveRecord::Migration
  def change
    rename_table :scoreboard_setups, :scoreboards
    rename_column :assessments, :has_scoreboard, :has_scoreboard_old
  end
end
