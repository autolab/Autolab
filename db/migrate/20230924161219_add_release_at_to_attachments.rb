class AddReleaseAtToAttachments < ActiveRecord::Migration[6.0]
  def change
    add_column :attachments, :release_at, :datetime, default: -> { 'CURRENT_TIMESTAMP' }
  end
end
