class AddEmbeddedQuizToAssessments < ActiveRecord::Migration[4.2]
  def change
  	 add_column :assessments, :embedded_quiz, :boolean
  end
end
