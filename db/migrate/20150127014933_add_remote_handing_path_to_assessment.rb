class AddRemoteHandingPathToAssessment < ActiveRecord::Migration
  def change
    add_column :assessments, :remote_handin_path, :string
  end
end
