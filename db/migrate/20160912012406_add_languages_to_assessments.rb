class AddLanguagesToAssessments < ActiveRecord::Migration
  def up
      add_column :assessments, :languages, :text
  end

  def down
      remove_column :assessments, :languages
  end
end
