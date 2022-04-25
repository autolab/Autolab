class AddGroupKeyToSubmissions < ActiveRecord::Migration[6.0]
  def up
    add_column :submissions, :group_key, :string, default: ""
    add_column :annotations, :group_key, :string, default: ""
  end

  def down
    remove_column :submissions, :group_key
    remove_column :annotations, :group_key
  end
end
