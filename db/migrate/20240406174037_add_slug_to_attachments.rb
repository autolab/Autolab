class AddSlugToAttachments < ActiveRecord::Migration[6.1]
  def change
    add_column :attachments, :slug, :string
    add_index :attachments, :slug, unique: true
  end
end
