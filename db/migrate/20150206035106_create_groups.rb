class CreateGroups < ActiveRecord::Migration
  def change
    create_table :groups do |t|
      t.string :name

      t.timestamps null: false
    end

    add_column :assessments, :group_size, :integer, default: 1
    add_reference :assessment_user_data, :group, null: true
  end
end
