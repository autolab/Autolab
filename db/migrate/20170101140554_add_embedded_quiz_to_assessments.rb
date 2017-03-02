class AddEmbeddedQuizToAssessments < ActiveRecord::Migration
  def change
  	 add_column :assessments, :embedded_quiz, :boolean
  end
end
