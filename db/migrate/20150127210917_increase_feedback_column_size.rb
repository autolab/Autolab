# frozen_string_literal: true

class IncreaseFeedbackColumnSize < ActiveRecord::Migration[4.2]
  def change
    change_column :scores, :feedback, :text, limit: 16_777_215
  end
end
