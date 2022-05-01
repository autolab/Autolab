class AddVersionBasedScoreDecaySettings < ActiveRecord::Migration[4.2]
  def self.up
    add_column :assessments, :version_threshold, :integer
    add_column :assessments, :version_penalty, :float
    add_column :courses, :version_threshold, :integer, :default => -1, :null => false
    add_column :courses, :version_penalty, :float, :default => 0, :null => false
  end

  def self.down
    remove_column :assessments, :version_threshold
    remove_column :assessments, :version_penalty
    remove_column :courses, :version_threshold
    remove_column :courses, :version_penalty
  end
end
