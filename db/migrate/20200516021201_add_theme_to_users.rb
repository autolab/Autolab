class AddThemeToUsers < ActiveRecord::Migration[5.2]
  def change
    add_column :users, :theme, :string
    change_column_default :users, :theme, "default"
  end
end
