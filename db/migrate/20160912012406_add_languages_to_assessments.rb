class AddLanguagesToAssessments < ActiveRecord::Migration[4.2]
  def up
      add_column :assessments, :languages, :text
  end

  def down
      remove_column :assessments, :languages
  end
end
