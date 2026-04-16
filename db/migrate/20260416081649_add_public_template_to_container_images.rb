class AddPublicTemplateToContainerImages < ActiveRecord::Migration[6.1]
  def change
    add_reference :container_images,
                  :public_template,
                  foreign_key: { to_table: :container_images },
                  null: true
  end
end
