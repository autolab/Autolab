class AddEmbeddedQuizFormAnswerToSubmissions < ActiveRecord::Migration[4.2]
  def change
  	 add_column :submissions, :embedded_quiz_form_answer, :text
  end
end
