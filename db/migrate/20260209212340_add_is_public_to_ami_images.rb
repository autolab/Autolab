class AddIsPublicToAmiImages < ActiveRecord::Migration[6.1]
  def change
    add_column :ami_images, :is_public, :boolean, null: false, default: false
    add_index  :ami_images, :is_public
  end
end
