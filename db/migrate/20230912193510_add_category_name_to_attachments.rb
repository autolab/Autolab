class AddCategoryNameToAttachments < ActiveRecord::Migration[6.0]
  def change
    add_column :attachments, :category_name, :string, default: "General"
  end
end
