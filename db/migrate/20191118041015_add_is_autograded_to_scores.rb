class AddIsAutogradedToScores < ActiveRecord::Migration
  def change
    add_column :scores, :is_autograded, :boolean, default: false
  end
end
