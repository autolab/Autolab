class CreateScoreAdjustments < ActiveRecord::Migration
  def self.up
    create_table :score_adjustments do |t|
	  t.integer :kind, :null => false
	  t.float :value, :null => false
    end
  end

  def self.down
    drop_table :score_adjustments
  end
end
