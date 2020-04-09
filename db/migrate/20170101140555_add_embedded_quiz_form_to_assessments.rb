class AddEmbeddedQuizFormToAssessments < ActiveRecord::Migration[4.2]
  def change
  	 add_column :assessments, :embedded_quiz_form, :binary
  end
end
