class AddDefaultProblemToProblems < ActiveRecord::Migration[6.1]
  def change
    add_column :problems, :starred, :boolean, default: false
  end
end
