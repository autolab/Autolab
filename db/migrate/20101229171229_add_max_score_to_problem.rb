class AddMaxScoreToProblem < ActiveRecord::Migration[4.2]
  def self.up
    add_column :problems, :max_score, :float, :default=>0
  end

  def self.down
    remove_column :problems, :max_score
  end
end
