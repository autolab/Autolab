class AddQuizToAssessments < ActiveRecord::Migration[4.2]
  def change
    add_column :assessments, :quiz, :boolean, :default => false
    add_column :assessments, :quizData, :text
  end
end
