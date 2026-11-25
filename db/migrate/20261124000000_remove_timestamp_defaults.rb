class RemoveTimestampDefaults < ActiveRecord::Migration[8.1]
  def change
    # Already-applied migrations are not rerun on existing installations.
    change_column_default :scheduler, :until, from: -> { 'CURRENT_TIMESTAMP' }, to: nil
    change_column_default :attachments, :release_at, from: -> { 'CURRENT_TIMESTAMP' }, to: nil
  end
end
