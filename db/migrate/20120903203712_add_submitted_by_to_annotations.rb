class AddSubmittedByToAnnotations < ActiveRecord::Migration
  def self.up
    add_column :annotations, :submitted_by, :string
  end

  def self.down
  end
end
