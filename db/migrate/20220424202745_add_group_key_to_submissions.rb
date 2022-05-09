class AddGroupKeyToSubmissions < ActiveRecord::Migration[6.0]
  def up
    add_column :submissions, :group_key, :string, default: ""
    add_reference :annotations, :group, index: true, default: nil
  end

  def down
    remove_column :submissions, :group_key
    remove_reference :annotations, :group
  end
end
