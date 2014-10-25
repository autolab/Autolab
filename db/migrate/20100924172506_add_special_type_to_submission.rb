class AddSpecialTypeToSubmission < ActiveRecord::Migration
  def self.up
    add_column :submissions, :special_type, :integer
  end

  def self.down
    remove_columnn :submissions, :special_type
  end
end
