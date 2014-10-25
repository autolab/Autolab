class AddMimeToSubmissions < ActiveRecord::Migration
  def self.up
    add_column :submissions, :mime_type, :string
  end

  def self.down
    remove_column :submissions, :mime_type
  end
end
