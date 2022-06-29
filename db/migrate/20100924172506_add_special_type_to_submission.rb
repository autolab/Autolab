class AddSpecialTypeToSubmission < ActiveRecord::Migration[4.2]
  def self.up
    add_column :submissions, :special_type, :integer
  end

  def self.down
    remove_columnn :submissions, :special_type
  end
end
