class AddOptionalToProblems < ActiveRecord::Migration
  def self.up
    add_column :problems, :optional, :boolean, :default => false
  end

  def self.down
    remove_column :problems, :optional
  end
end
