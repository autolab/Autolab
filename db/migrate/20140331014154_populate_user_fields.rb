class PopulateUserFields < ActiveRecord::Migration[4.2]
  def up
    User.find_each do |u|
      cuds = u.course_user_data

      school = nil
      major = nil
      year = nil

      cuds.find_each do |cud|
        school ||= cud.school
        major ||= cud.school
        year ||= cud.year
      end

      u.school = school
      u.major = major
      u.year = year
    end

    change_table :course_user_data do |cud|
      cud.rename :major, :major_backup
      cud.rename :school, :school_backup
      cud.rename :year, :year_backup
    end
  end

  def down
    change_table :course_user_data do |cud|
      cud.rename :major_backup, :major
      cud.rename :school_backup, :school
      cud.rename :year_backup, :year
    end
  end
end
