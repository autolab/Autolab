class CreateGroups < ActiveRecord::Migration
  def change
    create_table :groups do |t|
      t.string :name

      t.timestamps
    end

    change_table :assessments do |t|
      reversible do |dir|
        dir.up { remove_column :assessments, :has_partners }
        dir.down { add_column :assessments, :has_partners, :boolean }
      end
      t.column :group_size, :integer, default: 1
    end

    change_table :assessment_user_data do |t|
      t.column :group_id, :integer
      t.column :group_confirmed, :boolean, default: false
    end
  end
end
