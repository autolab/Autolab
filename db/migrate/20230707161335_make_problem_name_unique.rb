class MakeProblemNameUnique < ActiveRecord::Migration[6.0]
  def change
     add_index :problems, [:assessment_id, :name], unique: true, name: 'problem_uniq'

  end
end
