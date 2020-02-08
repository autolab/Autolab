class AddLateToCourse < ActiveRecord::Migration[4.2]
  def self.up
    add_column :courses, :late_slack, :integer
    add_column :courses, :grace_days, :integer
    add_column :courses, :late_penalty, :float
  end

  def self.down
    remove_column :courses, :late_slack
    remove_column :courses, :grace_days
    remove_column :courses, :late_penalty
  end
end
