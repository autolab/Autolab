class RemoveHasAutogradeOldFromAssessments < ActiveRecord::Migration[6.0]
  def change
    remove_column :assessments, :has_autograde_old, :boolean
  end
end
