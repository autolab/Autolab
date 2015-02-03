class CleanupOldFields < ActiveRecord::Migration
  def change

    remove_column :assessments, :late_penalty_old, :float
    remove_column :assessments, :version_penalty_old, :float

    remove_column :attachments, :type_old, :string
    remove_column :attachments, :foreign_key_old, :integer

    remove_column :course_user_data, :tweak_old, :float
    remove_column :course_user_data, :absolute_tweak, :boolean
    remove_column :course_user_data, :first_name_backup, :string
    remove_column :course_user_data, :last_name_backup, :string
    remove_column :course_user_data, :andrewID_backup, :string
    remove_column :course_user_data, :school_backup, :string
    remove_column :course_user_data, :major_backup, :string
    remove_column :course_user_data, :year_backup, :string
    remove_column :course_user_data, :email_backup, :string
    remove_column :course_user_data, :administrator_backup, :boolean


    remove_column :courses, :late_penalty_old, :float
    remove_column :courses, :version_penalty_old, :float

    remove_column :submissions, :tweak_old, :float
    remove_column :submissions, :ignored_old, :boolean
    remove_column :submissions, :absolute_tweak, :boolean

  end
end
