class AddReleaseAtToAttachments < ActiveRecord::Migration[6.0]
  def up
    add_column :attachments, :release_at, :datetime, default: -> { 'CURRENT_TIMESTAMP' }
    Attachment.find_each do |attachment|
      if attachment.released
        attachment.update(release_at: DateTime.now)
      else
        attachment.update(release_at: DateTime.now + 1.year)
      end
    end
  end
  def down
    Attachment.find_each do |attachment|
      attachment.update(released: attachment.release_at < DateTime.now)
    end
    remove_column :attachments, :release_at
  end
end
