class AddEmbeddedQuizFormDataToAssessments < ActiveRecord::Migration
  def change
  	 change_column :assessments, :embedded_quiz_form_data, :text
  end
end
