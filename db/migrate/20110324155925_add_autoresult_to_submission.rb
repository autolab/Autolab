class AddAutoresultToSubmission < ActiveRecord::Migration
  def self.up
    add_column :submissions, :autoresult, :text
  end

  def self.down
    remove_column :submissions, :autoresult
  end
end
