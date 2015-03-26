require "csv"
require "fileutils"
require "statistics.rb"

##
# this controller contains methods for system-wise
# admin functionality
class AdminsController < ApplicationController
  action_auth_level :show, :administrator
  def show
  end

  action_auth_level :email_instructors, :administrator
  def email_instructors
    return unless request.post?

    @cuds = CourseUserDatum.select(:user_id).distinct.joins(:course)
            .where("courses.end_date > ? and instructor = 1", DateTime.now)

    @email = CourseMailer.system_announcement(
      params[:from],
      make_dlist(@cuds),
      params[:subject],
      params[:body])
    @email.deliver
  end
end
