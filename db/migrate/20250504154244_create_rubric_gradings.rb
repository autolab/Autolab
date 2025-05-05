class CreateRubricGradings < ActiveRecord::Migration[6.1]
  def change
    create_table :rubric_gradings do |t|
      t.references :submission, null: false, foreign_key: true, type: :integer
      t.references :problem, null: false, foreign_key: true, type: :integer
      t.references :rubric_item, null: false, foreign_key: true, type: :bigint
      t.boolean :awarded
      t.text :comment

      t.timestamps
    end
  end
end
