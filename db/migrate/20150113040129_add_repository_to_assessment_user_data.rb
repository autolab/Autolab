class AddRepositoryToAssessmentUserData < ActiveRecord::Migration
  def change
    add_column :assessment_user_data, :repository, :string, null: true
  end
end
