class AddProblemValueToAnnotation < ActiveRecord::Migration[4.2]
  def self.up
    add_column :annotations, :comment, :text
    add_column :annotations, :value, :float
    add_column :annotations, :problem_id, :integer
    
  end

  def self.down
    remove_column :annotations, :comment
    remove_column :annotations, :value
    remove_column :annotations, :problem_id
  end
end
