class AddRemoteHandingPathToAssessment < ActiveRecord::Migration[4.2]
  def change
    add_column :assessments, :remote_handin_path, :string
  end
end
