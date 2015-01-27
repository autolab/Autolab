class IncreaseFeedbackColumnSize < ActiveRecord::Migration
  def change
    change_column :scores, :feedback, :text, limit: 16777215 
  end
end
