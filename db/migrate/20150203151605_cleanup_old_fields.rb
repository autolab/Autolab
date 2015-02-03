class CleanupOldFields < ActiveRecord::Migration
  def change

    remove_column :assessments, :late_penalty_old, :float
    remove_column :assessments, :version_penalty_old, :float

    remove_column :attachments, :type_old, :string
    remove_column :attachments, :foreign_key_old, :integer

    remove_column :course_user_data, :tweak_old, :float
    remove_column :course_user_data, :absolute_tweak, :boolean

    remove_column :courses, :late_penalty_old, :float
    remove_column :courses, :version_penalty_old, :float

    remove_column :submissions, :tweak_old, :float
    remove_column :submissions, :ignored_old, :boolean

  end
end
