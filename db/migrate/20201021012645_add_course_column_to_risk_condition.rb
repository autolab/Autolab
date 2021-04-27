class AddCourseColumnToRiskCondition < ActiveRecord::Migration[5.2]
  def up
    add_column :risk_conditions, :course_id, :integer
  end

  def down
    remove_column :risk_conditions, :course_id
  end
end
