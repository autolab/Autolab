class AddHasJoinedToCud < ActiveRecord::Migration

  def up

  	add_column :courses, :public, :boolean
    add_column :courses, :requires_permission, :boolean
    add_column :courses, :website_url, :string

    add_column :course_user_data, :has_joined, :boolean

    CourseUserDatum.all.each do |cud|
    	cud.has_joined = true
    	cud.save!
    end

  end

  def down

    remove_column :courses, :public
    remove_column :courses, :requires_permission
    remove_column :courses, :website_url
    remove_column :course_user_data, :has_joined

  end

end
