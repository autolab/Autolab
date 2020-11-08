class RenameColumnOfRiskCondition < ActiveRecord::Migration[5.2]
  def up
  	rename_column :risk_conditions, :type, :condition_type
  end

  def down
  	rename_column :risk_conditions, :condition_type, :type
  end
end
