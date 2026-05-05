class RemoveNameIndexFromContainerImages < ActiveRecord::Migration[6.1]
  def change
    remove_index :container_images, name: "index_container_images_on_name_public_only"
  end
end
