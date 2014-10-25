class AddDetectedMimeTypeToSubmissions < ActiveRecord::Migration
  def self.up
    add_column :submissions, :detected_mime_type, :string
  end

  def self.down
    remove_column :submissions, :detected_mime_type
  end
end
