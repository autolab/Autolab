class AddOptionalToProblems < ActiveRecord::Migration[4.2]
  def self.up
    add_column :problems, :optional, :boolean, :default => false
  end

  def self.down
    remove_column :problems, :optional
  end
end
