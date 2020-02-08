class AddMaxSizeToAssessments < ActiveRecord::Migration[4.2]
  def self.up
    add_column :assessments, :max_size, :integer, :default => 2
  end

  def self.down
    remove_column :assessments, :max_size
  end
end
