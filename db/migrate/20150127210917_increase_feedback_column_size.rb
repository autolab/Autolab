class IncreaseFeedbackColumnSize < ActiveRecord::Migration[4.2]
  def change
    change_column :scores, :feedback, :text, limit: 16777215 
  end
end
