class UpdateAmiImagesForImageBuilderMetadata < ActiveRecord::Migration[6.1]
  def up
    remove_column :ami_images, :packages, :json

    add_column :ami_images, :execution_arn, :string
    add_column :ami_images, :pipeline_arn,  :string
    add_column :ami_images, :recipe_arn,    :string
    add_column :ami_images, :component_arn, :string

    add_index :ami_images, :execution_arn
  end

  def down
    add_column :ami_images, :packages, :json, default: []

    remove_index :ami_images, :execution_arn

    remove_column :ami_images, :execution_arn
    remove_column :ami_images, :pipeline_arn
    remove_column :ami_images, :recipe_arn
    remove_column :ami_images, :component_arn
  end
end
