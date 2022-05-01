class AddSubmittedByToSubmission < ActiveRecord::Migration[4.2]
  def self.up
    add_column :submissions, :submitted_by_id, :integer 
  end

  def self.down
    remove_column :courses, :submitted_by_id
  end
end
