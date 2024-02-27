class RemoveVisibleAtFromAssessments < ActiveRecord::Migration[6.0]
  def change
    remove_column :assessments, :visible_at, :timestamp
  end
end
