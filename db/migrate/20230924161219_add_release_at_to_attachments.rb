class AddReleaseAtToAttachments < ActiveRecord::Migration[6.0]
  def up
    add_column :attachments, :release_at, :datetime
    Attachment.where(released: true).update_all(release_at: Time.current)
    Attachment.where(released: false).update_all(release_at: Time.current + 1.year)
  end
  def down
    # Rollback policy: a NULL release_at means the attachment was not released.
    # Bypass current model validations and callbacks when updating legacy rows.
    execute <<~SQL
      UPDATE attachments
      SET released = release_at IS NOT NULL AND release_at < #{connection.quote(Time.current)}
    SQL
    remove_column :attachments, :release_at
  end
end
