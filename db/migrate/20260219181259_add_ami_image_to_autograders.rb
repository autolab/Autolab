class AddAmiImageToAutograders < ActiveRecord::Migration[6.1]
  def change
    add_column :autograders, :use_ami_image, :boolean, default: false, null: false
    add_reference :autograders, :ami_image, foreign_key: true
  end
end
