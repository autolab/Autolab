class RemoveHasScoreboardOldFromAssessments < ActiveRecord::Migration[6.0]
  def change
    remove_column :assessments, :has_scoreboard_old, :boolean
  end
end
