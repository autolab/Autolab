class AddDockerfileContentsToContainerImages < ActiveRecord::Migration[6.1]
  def change
    add_column :container_images, :dockerfile_contents, :text
  end
end
