class CreateRubricItemAssignments < ActiveRecord::Migration[6.1]
  def change
    create_table :rubric_item_assignments do |t|
      t.references :rubric_item, null: false, foreign_key: true
      t.references :submission, null: false, foreign_key: true
      t.boolean :assigned, default: false

      t.timestamps
    end
    
    # Add index for faster lookups
    add_index :rubric_item_assignments, [:rubric_item_id, :submission_id], unique: true, name: 'index_ria_on_rubric_item_id_and_submission_id'
    
    # Remove assigned column from rubric_items as it will now be tracked per submission
    remove_column :rubric_items, :assigned, :boolean
  end
end
