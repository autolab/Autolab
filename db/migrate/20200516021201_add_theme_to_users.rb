class AddThemeToUsers < ActiveRecord::Migration[5.2]
  def change
    add_column :users, :theme, :string
    change_column_null :users, :theme, false
    change_column_default :users, :theme, from: "", to: "default"
  end
end
