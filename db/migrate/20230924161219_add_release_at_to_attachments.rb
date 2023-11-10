class AddReleaseAtToAttachments < ActiveRecord::Migration[6.0]
  def up
    add_column :attachments, :release_at, :datetime, default: -> { 'CURRENT_TIMESTAMP' }
    Attachment.where(released: true).update_all(release_at: DateTime.now)
    Attachment.where(released: false).update_all(release_at: DateTime.now + 1.year)
  end
  def down
    Attachment.find_each do |attachment|
      attachment.update(released: attachment.release_at < DateTime.now)
    end
    remove_column :attachments, :release_at
  end
end
