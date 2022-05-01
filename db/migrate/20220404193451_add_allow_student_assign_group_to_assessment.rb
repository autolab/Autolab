class AddAllowStudentAssignGroupToAssessment < ActiveRecord::Migration[6.0]
  def up
    add_column :assessments, :allow_student_assign_group, :boolean, default: true
  end

  def down
    remove_column :assessments, :allow_student_assign_group
  end
end
