class AddIncludeInstructorsToScoreboard < ActiveRecord::Migration[6.1]
  def change
    add_column :scoreboards, :include_instructors, :boolean, default: false
  end
end
