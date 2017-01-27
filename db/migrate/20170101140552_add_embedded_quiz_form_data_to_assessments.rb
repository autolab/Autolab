class AddEmbeddedQuizFormDataToAssessments < ActiveRecord::Migration
  def change
  	 add_column :assessments, :embedded_quiz_form_data, :text
  end
end
