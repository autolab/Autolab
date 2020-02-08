class AddHasAutogradeKeyToAssessment < ActiveRecord::Migration[4.2]
  def change
    add_column :assessments, :has_autograde, :boolean
    add_column :assessments, :has_partners, :boolean
    add_column :assessments, :has_scoreboard, :boolean
    add_column :assessments, :has_svn, :boolean
  end
end
