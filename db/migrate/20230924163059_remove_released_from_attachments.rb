class RemoveReleasedFromAttachments < ActiveRecord::Migration[6.0]
  def change
    remove_column :attachments, :released, :boolean
  end
end
