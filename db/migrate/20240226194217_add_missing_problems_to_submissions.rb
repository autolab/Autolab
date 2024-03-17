class AddMissingProblemsToSubmissions < ActiveRecord::Migration[6.1]
  def change
    add_column :submissions, :missing_problems, :text
  end
end
