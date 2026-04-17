class AllowNullImageUriOnContainerImages < ActiveRecord::Migration[6.1]
  def change
    change_column_null :container_images, :image_uri, true
  end
end
