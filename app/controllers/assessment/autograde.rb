require "uri"
require "tango_client"
require_relative Rails.root.join("config", "autogradeConfig.rb")

##
# Contains all functions related to autograding, including functions to send autograding jobs,
#   the callback route for when jobs are completed, and regrading routes.
# Gets imported into AssessmentsController
#
module AssessmentAutograde
  # method called when Tango returns the output
  # action_no_auth :autograde_done
  def autograde_done
    @assessment = @course.assessments.find_by(name: params[:name])
    render(nothing: true) && return unless @assessment && @assessment.has_autograder?

    # there can be multiple submission with the same dave if this was a group submission
    submissions = Submission.where(dave: params[:dave]).all

    feedback_str = params[:file].read

    COURSE_LOGGER.log("autograde_done")
    COURSE_LOGGER.log("autograde_done hit: #{request.fullpath}")

    extend_config_module(@assessment, submissions[0], @cud)

    require_relative(Rails.root.join("assessmentConfig", "#{@course.name}-#{@assessment.name}.rb"))

    if @assessment.overwrites_method?(:autogradeDone)
      @assessment.config_module.autogradeDone(submissions, feedback_str)
    else
      autogradeDone(submissions, feedback_str)
    end

    render(nothing: true) && return
  rescue
    Rails.logger.error "Exception in autograde_done"
    render(nothing: true) && return
  end

  # RESTfully speaking, this belongs in submissions controller,
  #   but because it uses autograding, it is easier to have it here
  # action_auth_level :regrade, :instructor
  def regrade
    @submission = @assessment.submissions.find(params[:submission_id])
    @effective_cud = @submission.course_user_datum

    unless @assessment.has_autograder?
      # Not an error, this behavior was specified!
      flash[:info] = "This submission is not autogradable"
      redirect_to([:history, @course, @assessment, cud_id: @effective_cud.id]) && return
    end

    autogradeSubmissions(@course, @assessment, [@submission])

    redirect_to([:history, @course, @assessment, cud_id: @effective_cud.id]) && return
  end

  #
  # regradeBatch - regrade the selected submissions by the instructor
  #
  # action_auth_level :regradeBatch, :instructor
  def regradeBatch
    submission_ids = params[:submission_ids]

    # Now regrade only the most recent submissions. Keep track of
    # any handins that fail.
    failed_jobs = 0
    failed_list = ""

    submission_ids.each do |submission_id|
      submission = @assessment.submissions.find_by_id(submission_id)
      if submission
        job = autogradeSubmissions(@course, @assessment, [submission])
        if job == -2 # no autograding properties for this assessment
          redirect_to([@course, @assessment, :submissions]) && return
        elsif job < 0 # autograding failed
          failed_jobs += 1
          failed_list += "#{@submission.filename}: autograding error.<br>"
        end
      else
        failed_jobs += 1
        failed_list += "#{submission.filename}: not found or not readable.<br>"
      end
    end

    flash[:error] = "Warning: Could not regrade #{failed_jobs} submission(s):<br>" + failed_list if failed_jobs > 0

    success_jobs = submission_ids.size - failed_jobs
    if success_jobs > 0
      link = "<a href=\"#{url_for(controller: 'jobs')}\">#{success_jobs} submission</a>"
      flash[:success] = ("Regrading #{link}").html_safe
    end

    redirect_to([@course, @assessment, :submissions]) && return
  end

  #
  # regradeAll - regrade the most recent submissions from each student
  #
  # RESTfully speaking, this belongs in submissions controller,
  #   but because it uses autograding, it is easier to have it here
  # action_auth_level :regradeAll, :instructor
  def regradeAll
    # Grab all of the submissions for this assessment
    @submissions = @assessment.submissions.where(special_type: Submission::NORMAL)
                   .order("version DESC")

    last_submissions = @submissions.latest

    # Now regrade only the most recent submissions. Keep track of
    # any handins that fail.
    failed_jobs = 0
    failed_list = ""
    last_submissions.each do |submission|
      if submission
        job = autogradeSubmissions(@course, @assessment, [submission])
        if job == -2 # no autograding properties for this assessment
          redirect_to([@course, @assessment, :submissions]) && return
        elsif job < 0 # autograding failed
          failed_jobs += 1
          failed_list += "#{@submission.filename}: autograding error.<br>"
        end
      else
        failed_jobs += 1
        failed_list += "#{submission.filename}: not found or not readable.<br>"
      end
    end

    flash[:error] = "Warning: Could not regrade #{failed_jobs} submission(s):<br>" + failed_list if failed_jobs > 0

    success_jobs = last_submissions.size - failed_jobs
    if success_jobs > 0
      link = "<a href=\"#{url_for(controller: 'jobs')}\">#{success_jobs} students</a>"
      flash[:success] = ("Regrading the most recent submissions from #{link}").html_safe
    end

    redirect_to([@course, @assessment, :submissions]) && return
  end

  ##
  # autogradeSubmissions - submits an autograding job to Tango.
  # Called by assessments#handin, submissions#regrade and submissions#regradeAll
  # returns the job status returned by sendJob
  def autogradeSubmissions(course, assessment, submissions)
    # Check for nil first, since students should know about this
    flash[:error] = "Submission could not be autograded due to an error in creation" && return if submissions.blank?

    job = sendJob(course, assessment, submissions, @cud)
    if job == -2
      flash[:error] = "Autograding failed because there are no autograding properties."
      if @cud.instructor?
        link = (view_context.link_to "Autograder Settings", [:edit, course, assessment, :autograder])
        flash[:error] += " Visit #{link} to set the autograding properties."
      else
        flash[:error] += " Please contact your instructor."
      end
    elsif job == -1
      link = "<a href=\"#{url_for(controller: 'jobs')}\">Jobs</a>"
      flash[:error] = "There was an error submitting your autograding job. We are likely down for maintenance if issues persist, please contact #{Rails.configuration.school['support_email']}"
    elsif job == -3 || job == -4 || job == -6
      flash[:error] = "There was an error uploading the submission file. (Error #{job})"
    elsif job == -9
      flash[:error] = "Submission was rejected by autograder."
      if @cud.instructor?
        link = (view_context.link_to "Autograder Settings", [:edit, course, assessment, :autograder])
        flash[:error] += " (Verify the autograding properties at #{link}.)"
      end
		elsif job == -10
			flash[:error] = "One or more files in the Autograder module don't exist. Contact the instructor."
		elsif job < 0
      flash[:error] = "Autograding failed because of an unexpected exception in the system."
    else
      link = "<a href=\"#{url_for(controller: 'jobs', action: 'getjob', id: job)}\">Job ID = #{job}</a>"
      flash[:success] = ("Submitted file #{submissions[0].filename} (#{link}) for autograding." \
        " Refresh the page to see the results.").html_safe
    end
    job
  end

end
