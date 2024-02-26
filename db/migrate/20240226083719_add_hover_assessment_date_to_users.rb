class AddHoverAssessmentDateToUsers < ActiveRecord::Migration[6.1]
  def change
    add_column :users, :hover_assessment_date, :boolean
  end
end
