require 'csv'
require 'fileutils'
require 'Statistics.rb'

# this controller contains methods for system-wise
# admin functionality
class AdminsController < ApplicationController

  action_auth_level :show, :administrator
  def show
  end

  action_auth_level :emailInstructors, :administrator
  def emailInstructors
    if request.post? then
      

      @cuds = CourseUserDatum.select(:user_id).distinct.joins(:course)
        .where("courses.end_date > ? and instructor = 1", DateTime.now)

      # select(:user_id).distinct.where(:instructor=>true)
      # @cuds = Course.where(:temporal_status => :current ).instructors
      bccString = makeDlist(@cuds)

      @email = CourseMailer.system_announcement(
            params[:from],
            bccString,
            params[:subject],
            params[:body])
      @email.deliver

    end
  end

end
