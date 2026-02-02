class AddAmiIdToAmiImages < ActiveRecord::Migration[6.1]
  def change
    add_column :ami_images, :ami_id, :string
    add_index :ami_images, :ami_id, unique: true
  end
end
