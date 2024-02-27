class RemoveSvnData < ActiveRecord::Migration[6.1]
  def change
    remove_column :assessments, :has_svn, :boolean, if_exists: true
    remove_column :assessment_user_data, :repository, :string, if_exists: true
  end
end
