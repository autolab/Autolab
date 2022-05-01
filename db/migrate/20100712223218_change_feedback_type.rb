class ChangeFeedbackType < ActiveRecord::Migration[4.2]
  def self.up
    change_column :scores, :feedback, :text
  end

  def self.down
    change_column :scores, :feedback, :string
  end
end
