class AddReleaseAtToAttachments < ActiveRecord::Migration[6.0]
  def up
    add_column :attachments, :release_at, :datetime
    Attachment.where(released: true).update_all(release_at: Time.current)
    Attachment.where(released: false).update_all(release_at: Time.current + 1.year)
  end
  def down
    # Rollback policy: a NULL release_at means the attachment was not released.
    Attachment.find_each do |attachment|
      released = attachment.release_at.present? && attachment.release_at < Time.current
      attachment.update(released: released)
    end
    remove_column :attachments, :release_at
  end
end
