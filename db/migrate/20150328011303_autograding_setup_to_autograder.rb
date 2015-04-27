class AutogradingSetupToAutograder < ActiveRecord::Migration
  def change
    rename_table :autograding_setups, :autograders
    rename_column :assessments, :has_autograde, :has_autograde_old
  end
end
