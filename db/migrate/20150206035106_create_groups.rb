class CreateGroups < ActiveRecord::Migration[4.2]
  def change
    create_table :groups do |t|
      t.string :name

      t.timestamps null: false
    end

    add_column :assessments, :group_size, :integer, default: 1
    add_reference :assessment_user_data, :group, null: true
    add_column :assessment_user_data, :membership_status, :integer, limit: 1, default: 0
  end
end
