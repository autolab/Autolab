class AddDefaultProblemToProblems < ActiveRecord::Migration[6.1]
  def change
    add_column :problems, :favorite, :boolean, default: false
  end
end
