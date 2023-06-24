class AddDisabledToScheduler < ActiveRecord::Migration[6.0]
  def change
    add_column :scheduler, :disabled, :boolean, default: false
  end
end
