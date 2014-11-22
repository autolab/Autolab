class AddColumnAutogradeKeyToAssessments < ActiveRecord::Migration
  def change
    change_table :submissions do |t|
      t.string :dave, null: true
    end
  end
end
