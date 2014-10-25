# Production
require 'net/http'
require 'json'
require 'pathname'
require_relative "../ModuleBase.rb"
require_relative "../autoConfig.rb"
require "digest/md5"


#include ModuleBase

# The Autograde module overrides the handin action and provides the
# 'autogradeDone' action which is called by Tango on completion of a job to
# notify Autolab 
module Autograde
  include ModuleBase

  # 
  # regrade - regrades a submission from a user
  #
  def regrade
    @submission = Submission.find(params[:id])
    @effectiveCud = @submission.course_user_datum
    @course = @submission.course_user_datum.course
    @assessment = @submission.assessment

    if ! autograde?(@submission) then
      # Not an error, this behavior was specified!
      flash[:info] = "This submission is not autogradable"
      redirect_to :action=>"history", :id=>@effectiveCud.id and return -3
    end
    jobid = createVm()
    if jobid == -2 then 
      link = "<a href=\"#{url_for(:action=>'adminAutograde')}\">Admin Autograding</a>"
      flash[:error] = "Autograding failed because there are no autograding properties. " +
        " Visit #{link} to set the autograding properties."
    elsif jobid == -1 then 
      link = "<a href=\"#{url_for(:controller=>'jobs')}\">Jobs</a>"
      flash[:error] = "There was an error submitting your autograding job. " +
        "Check the #{link} page for more info."
    else
      link = "<a href=\"#{url_for(:controller=>'jobs')}\">Job ID = #{jobid}</a>"
      flash[:success] = ("Success: Regrading #{@submission.filename} (#{link})").html_safe
    end
    
    redirect_to history_course_assessment_path(@course, @assessment) and return
  end

  protected

  # 
  # autograderDev - This page allows backend debuggers to launch
  # autograding jobs to arbitrary Tango ports.
  #
  def autograderDev
    if not @cud.instructor? then
      redirect :action=>"index" and return
    end
    if request.post? then
      @jobs = []
      @tangoHost = params[:tangoHost]
      @tangoPort = params[:tangoPort].to_i
      debug = params[:debug]

      if params[:file] then
        @submission = Submission.create(:assessment_id=>@assessment.id,
					:course_user_datum_id=>@cud.id)
        @submission.saveFile(params)
        job = createVm()
        @jobs << job 
      end
      if (params[:regrade] ) and params[:regrade][:submission_id].length > 0	then

        for sub_id in params[:regrade][:submission_id] do
          @submission = Submission.find(sub_id)
          if @submission then
            job = createVm()
            @jobs << "Regrading Submission #{@submission.id}, job id #{job}" 
          end
        end
      end
    end
    @submissions = @assessment.submissions.include(:course_user_datum).order("course_user_datum_id")
    render(:file=>"lib/modules/views/autograderDev.html.erb",
           :layout=>true) and return 
  end

  #private

end

