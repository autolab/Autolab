class AddMaxSizeToAssessments < ActiveRecord::Migration
  def self.up
    add_column :assessments, :max_size, :integer, :default => 2
  end

  def self.down
    remove_column :assessments, :max_size
  end
end
