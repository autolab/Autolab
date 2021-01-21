class CreateRiskConditions < ActiveRecord::Migration[5.2]
  def up
    create_table :risk_conditions do |t|
      t.integer :type
      t.text :parameters
      t.integer :version
      t.timestamps
    end
  end

  def down
  	drop_table :risk_conditions
  end
end
