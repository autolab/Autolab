class CreateContainerImages < ActiveRecord::Migration[6.1]
  def change
    create_table :container_images do |t|
      t.string  :name, null: false
      t.integer :status, default: 0, null: false
      t.string  :image_uri, null: false
      t.integer :build_id
      t.integer :course_id
      t.boolean :is_public, default: false, null: false

      t.timestamps
    end

    add_index :container_images, :course_id
    add_index :container_images, :image_uri, unique: true
    add_index :container_images, :is_public
    add_index :container_images, :status
  end
end
