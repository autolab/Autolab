class AddTextfieldsToAssessments < ActiveRecord::Migration[4.2]
  def up
      add_column :assessments, :textfields, :text
  end

  def down
      remove_column :assessments, :textfields
  end
end
