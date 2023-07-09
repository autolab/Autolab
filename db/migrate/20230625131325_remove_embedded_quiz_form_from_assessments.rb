class RemoveEmbeddedQuizFormFromAssessments < ActiveRecord::Migration[6.0]
  def change
    remove_column :assessments, :embedded_quiz_form, :binary
  end
end
