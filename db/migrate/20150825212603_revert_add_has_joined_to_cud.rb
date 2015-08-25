class RevertAddHasJoinedToCud < ActiveRecord::Migration
  def up

    remove_column :courses, :public
    remove_column :courses, :requires_permission
    remove_column :courses, :website_url
    remove_column :course_user_data, :has_joined

  end

  def down

    add_column :courses, :public, :boolean, :default => false
    add_column :courses, :requires_permission, :boolean, :default => true
    add_column :courses, :website_url, :string

    add_column :course_user_data, :has_joined, :boolean

    CourseUserDatum.find_each do |cud|
      cud.has_joined = true

      if !cud.nickname.nil? then
        # if there is a non-ascii nickname, we migrate it too
        cud.nickname.gsub!(/\P{ASCII}/, '')
      end

      cud.save!
    end

  end
end
