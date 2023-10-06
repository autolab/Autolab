class AddUntilToScheduler < ActiveRecord::Migration[6.0]
  def change
    add_column :scheduler, :until, :datetime, default: -> { 'CURRENT_TIMESTAMP' }
  end
end
