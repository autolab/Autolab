class AddRubricItemIdToAnnotations < ActiveRecord::Migration[6.1]
  def change
    add_reference :annotations, :rubric_item, foreign_key: true, null: true
  end
end
