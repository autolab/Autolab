##
# this controller contains methods for system-wise
# admin functionality
class AdminsController < ApplicationController
  skip_before_action :set_course

  action_auth_level :email_instructors, :administrator
  def email_instructors
    @users = User.select(:email).joins(:course_user_data).distinct
                 .where(course_user_data: { instructor: true })
                 .order('email ASC')

    return unless request.post?

    @email = CourseMailer.system_announcement(
      params[:from],
      make_dlist(@cuds),
      params[:subject],
      params[:body]
    )
    @email.deliver
  end

  action_auth_level :github_integration, :administrator
  def github_integration
    @github_integration = GithubIntegration.check_github_authorization
  end

  action_auth_level :clear_cache, :administrator
  def clear_cache
    Rails.cache.cleanup
    flash[:success] = "Cache Cleared"
    redirect_back(fallback_location: root_path)
  end
end
