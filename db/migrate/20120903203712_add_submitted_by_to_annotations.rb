class AddSubmittedByToAnnotations < ActiveRecord::Migration[4.2]
  def self.up
    add_column :annotations, :submitted_by, :string
  end

  def self.down
  end
end
