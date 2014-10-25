class AddAutogradeAndScoreboardSettingsToAssessment < ActiveRecord::Migration
  def change
    rename_table :autograde_props, :autograding_setups
    rename_table :scoreboard_props, :scoreboard_setups
  end
end
