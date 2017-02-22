##
# this controller contains methods for system-wise
# admin functionality
class AdminsController < ApplicationController
    rescue_from ActionView::MissingTemplate do |exception|
      redirect_to("/home/error_404")
  end
  action_auth_level :show, :administrator
  def show
  end

  action_auth_level :email_instructors, :administrator
  def email_instructors
    @cuds = CourseUserDatum.select(:user_id).distinct.joins(:course).joins(:user)
            .where(instructor: true)
            .order("users.email ASC")

    return unless request.post?

    @email = CourseMailer.system_announcement(
      params[:from],
      make_dlist(@cuds),
      params[:subject],
      params[:body])
    @email.deliver
  end
end
