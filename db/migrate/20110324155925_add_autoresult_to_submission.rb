class AddAutoresultToSubmission < ActiveRecord::Migration[4.2]
  def self.up
    add_column :submissions, :autoresult, :text
  end

  def self.down
    remove_column :submissions, :autoresult
  end
end
