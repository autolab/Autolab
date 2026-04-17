class AddUniqueIndexToNameForPublic < ActiveRecord::Migration[6.1]
  def change
    add_index :container_images,
              :name,
              unique: true,
              where: "is_public = true",
              name: "index_container_images_on_name_public_only"
  end
end
