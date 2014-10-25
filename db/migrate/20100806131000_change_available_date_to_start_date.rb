class ChangeAvailableDateToStartDate < ActiveRecord::Migration
  def self.up
  rename_column :assessments, :available_date, :start_date
  end

  def self.down
  rename_column :assessments, :start_date, :available_date 
  end
end
