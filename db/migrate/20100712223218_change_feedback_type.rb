class ChangeFeedbackType < ActiveRecord::Migration
  def self.up
    change_column :scores, :feedback, :text
  end

  def self.down
    change_column :scores, :feedback, :string
  end
end
