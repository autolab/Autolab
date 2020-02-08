class ChangeAvailableDateToStartDate < ActiveRecord::Migration[4.2]
  def self.up
  rename_column :assessments, :available_date, :start_date
  end

  def self.down
  rename_column :assessments, :start_date, :available_date 
  end
end
