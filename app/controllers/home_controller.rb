##
# The Home Controller houses (ha) any action that's available to the general public.
#
class HomeController < ApplicationController
  skip_before_action :authenticate_user!
  skip_before_action :set_course
  skip_before_action :authorize_user_for_course
  skip_before_action :authenticate_for_action
  skip_before_action :update_persistent_announcements

  def developer_login
    return unless request.post?

    user = User.find_by(email: params[:email])
    if user
      sign_in :user, user
      flash[:success] = "Signed in as #{user.display_name}"
      redirect_to(root_path)
    else
      flash[:error] = "User with Email: '#{params[:email]}' doesn't exist"
      redirect_to home_developer_login_path
    end
  end

  def contact
    @student_course_contacts = build_student_course_contacts
    @instance_manager_email = school_config_value("instance_manager_email") ||
                              school_config_value("support_email")
    @developer_email = school_config_value("developer_email") ||
                       school_config_value("tech_email") ||
                       "autolab-dev@andrew.cmu.edu"

    @show_staff_cta = user_can_contact_instance_manager?
    @show_dev_cta = user_can_contact_dev_team?
    @show_sponsor_panel = user_can_manage_sponsors?
  end

  def sponsors
    unless user_can_manage_sponsors?
      flash[:error] = "Permission denied."
      redirect_to(home_contact_path) && return
    end

    @instance_manager_email = school_config_value("instance_manager_email") ||
                              school_config_value("support_email")
    raw_sponsors = Array.wrap(Rails.configuration.school["sponsors"])
    @sponsors = raw_sponsors.filter_map do |entry|
      next unless entry.is_a?(Hash)

      entry.symbolize_keys
    end
  end

  def error_404; end

  def error_500; end

private

  def school_config_value(key)
    Rails.configuration.school[key]
  end

  def build_student_course_contacts
    return [] unless current_user

    cuds = current_user.course_user_data.includes(course: { course_user_data: :user })

    cuds.each_with_object([]) do |cud, collection|
      next if cud.instructor? || cud.course_assistant? || cud.dropped?

      instructors = cud.course.course_user_data.select(&:instructor?).filter_map do |icud|
        icud.user&.email
      end.uniq

      next if instructors.empty?

      collection << { course: cud.course, instructors: }
    end
  end

  def user_can_contact_instance_manager?
    return false unless current_user

    current_user.staff? || current_user.administrator?
  end

  def user_can_manage_sponsors?
    user_can_contact_instance_manager?
  end

  def normalized_instance_manager_emails
    value = school_config_value("instance_manager_email")
    Array(value).flat_map do |entry|
      entry.to_s.split(/[;,]/)
    end.map { |email| email.strip.downcase }.reject(&:blank?)
  end

  def user_can_contact_dev_team?
    return false unless current_user

    return true if current_user.administrator?

    normalized_instance_manager_emails.include?(current_user.email.downcase)
  end
end
