class AddDetectedMimeTypeToSubmissions < ActiveRecord::Migration[4.2]
  def self.up
    add_column :submissions, :detected_mime_type, :string
  end

  def self.down
    remove_column :submissions, :detected_mime_type
  end
end
