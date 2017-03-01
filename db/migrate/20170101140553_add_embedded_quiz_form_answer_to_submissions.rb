class AddEmbeddedQuizFormAnswerToSubmissions < ActiveRecord::Migration
  def change
  	 add_column :submissions, :embedded_quiz_form_answer, :text
  end
end
