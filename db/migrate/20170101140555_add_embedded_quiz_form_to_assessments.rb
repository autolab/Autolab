class AddEmbeddedQuizFormToAssessments < ActiveRecord::Migration
  def change
  	 add_column :assessments, :embedded_quiz_form, :binary
  end
end
