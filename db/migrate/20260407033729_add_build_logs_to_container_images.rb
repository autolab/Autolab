class AddBuildLogsToContainerImages < ActiveRecord::Migration[6.1]
  def change
    add_column :container_images, :build_logs, :text, default: "", null: false
  end
end
