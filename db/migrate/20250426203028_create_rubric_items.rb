class CreateRubricItems < ActiveRecord::Migration[6.1]
  def change
    create_table :rubric_items do |t|
      t.references :problem, null: false, foreign_key: true, type: :integer
      t.string :description, null: false
      t.float :points, null: false
      t.integer :order, null: false
      t.timestamps
    end

    add_index :rubric_items, [:problem_id, :order], unique: true
  end
end 