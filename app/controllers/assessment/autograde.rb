require "uri"
require "tango_client"
require_relative Rails.root.join("config", "autogradeConfig.rb")

##
# Contains all functions related to autograding, including functions to send autograding jobs,
#   the callback route for when jobs are completed, and regrading routes.
# Gets imported into AssessmentsController
#
module AssessmentAutograde

  include AssessmentAutogradeCore

  # method called when Tango returns the output
  # action_no_auth :autograde_done
  def autograde_done
    @assessment = @course.assessments.find_by(name: params[:name])
    head(:no_content) && return unless @assessment && @assessment.has_autograder?
    ASSESSMENT_LOGGER.setAssessment(@assessment)

    # there can be multiple submission with the same dave if this was a group submission
    submissions = Submission.where(dave: params[:dave]).all

    feedback_str = params[:file].read

    COURSE_LOGGER.log("autograde_done")
    COURSE_LOGGER.log("autograde_done hit: #{request.fullpath}")

    extend_config_module(@assessment, submissions[0], @cud)

    if (@assessment.use_unique_module_name)
      require_relative(@assessment.unique_config_file_path)
    else
      require_relative(Rails.root.join("assessmentConfig", "#{@course.name}-#{@assessment.name}.rb"))
    end

    if @assessment.overwrites_method?(:autogradeDone)
      @assessment.config_module.autogradeDone(submissions, feedback_str)
    else
      autogradeDone(submissions, feedback_str)
    end

    head(:no_content) && return
  rescue => exception
    ExceptionNotifier.notify_exception(exception, env: request.env,
                                       data: {
                                         user: current_user,
                                         course: @course,
                                         assessment: @assessment,
                                         submission: @submission
                                       })
    Rails.logger.error "Exception in autograde_done: #{exception.class} (#{exception.message})"
    COURSE_LOGGER.log "Exception in autograde_done: #{exception.class} (#{exception.message})"
    head(:no_content) && return
  end

  # RESTfully speaking, this belongs in submissions controller,
  #   but because it uses autograding, it is easier to have it here
  # action_auth_level :regrade, :instructor
  def regrade
    @submission = @assessment.submissions.find(params[:submission_id])
    @effective_cud = @submission.course_user_datum

    unless @assessment.has_autograder?
      # Not an error, this behavior was specified!
      flash[:notice] = "This submission is not autogradable"
      redirect_to([:history, @course, @assessment, cud_id: @effective_cud.id]) && return
    end

    begin
      sendJob_AddHTMLMessages(@course, @assessment, [@submission])
    rescue AssessmentAutogradeCore::AutogradeError => e
      # error message already filled in by sendJob_AddHTMLMessages, we just
      # log the error message
      COURSE_LOGGER.log("SendJob failed for #{@submission.id}\n
        User error message: #{flash[:error]}\n
        error name: #{e.error_code}\n
        additional error data: #{e.additional_data}")
    end

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
    submissions = submission_ids.map {|sid| @assessment.submissions.find_by_id(sid)}

    begin
      failed_list = sendJob_batch(@course, @assessment, submissions, @cud)
    rescue AssessmentAutogradeCore::AutogradeError => e
      if e.error_code == :missing_autograding_props
        # no autograding properties for this assessment
        flash[:error] = "Autograding failed because there are no autograding properties."
        redirect_to([@course, @assessment, :submissions]) && return
      end
    end

    failure_jobs = failed_list.length
    if failure_jobs > 0
      flash[:error] = "Warning: Could not regrade #{ActionController::Base.helpers.pluralize(failure_jobs, "submission")}:<br>"
      failed_list.each do |failure|
        if failure[:error].error_code == :nil_submission
          flash[:error] += "Unrecognized submission ID<br>"
        else
          flash[:error] += "#{failure[:submission].filename}: #{failure[:error].message}<br>"
        end
      end
    end

    success_jobs = submission_ids.size - failure_jobs
    if success_jobs > 0
      link = "<a href=\"#{url_for(controller: 'jobs')}\">#{ActionController::Base.helpers.pluralize(success_jobs, "submission")}</a>"
      flash[:success] = ("Regrading #{link}")
    end

    # For both :success and :error
    flash[:html_safe] = true

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

    begin
      failed_list = sendJob_batch(@course, @assessment, last_submissions, @cud)
    rescue AssessmentAutogradeCore::AutogradeError => e
      if e.error_code == :missing_autograding_props
        # no autograding properties for this assessment
        flash[:error] = "Autograding failed because there are no autograding properties."
        redirect_to([@course, @assessment, :submissions]) && return
      end
    end

    failure_jobs = failed_list.length
    if failure_jobs > 0
      flash[:error] = "Warning: Could not regrade #{ActionController::Base.helpers.pluralize(failure_jobs, "submission")}:<br>"
      failed_list.each do |failure|
        if failure[:error].error_code == :nil_submission
          flash[:error] += "Unrecognized submission ID<br>"
        else
          flash[:error] += "#{failure[:submission].filename}: #{failure[:error].message}<br>"
        end
      end
    end

    success_jobs = last_submissions.size - failure_jobs
    if success_jobs > 0
      link = "<a href=\"#{url_for(controller: 'jobs')}\">#{ActionController::Base.helpers.pluralize(success_jobs, "student")}</a>"
      flash[:success] = ("Regrading the most recent submissions from #{link}")
    end

    # For both :success and :error
    flash[:html_safe] = true

    redirect_to([@course, @assessment, :submissions]) && return
  end

  ##
  # sendJob_AddHTMLMessages - A wrapper for AssessmentAutogradeCore::sendJob that adds error
  #   or congratulatory messages to flash depending on the result of sendJob. Note that this
  #   function does not "handle" the AutogradeError, it just adds messages depending on the
  #   situation, so the caller of this function will still receive the original error from 
  #   sendJob.
  # 
  # Called by assessments#handin, submissions#regrade and submissions#regradeAll
  #
  # On success, returns the job id
  # On failure, enters error message into flash[:error] and raises the original AutogradeError.
  #
  def sendJob_AddHTMLMessages(course, assessment, submissions)
    # Check for nil first, since students should know about this
    flash[:error] = "Submission could not be autograded due to an error in creation" && return if submissions.blank?

    begin
      job = sendJob(course, assessment, submissions, @cud)
    rescue AssessmentAutogradeCore::AutogradeError => e
      case e.error_code
      when :missing_autograding_props
        flash[:error] = "Autograding failed because there are no autograding properties."
        if @cud.instructor?
          link = (view_context.link_to "Autograder Settings", [:edit, course, assessment, :autograder])
          flash[:error] += " Visit #{link} to set the autograding properties."
          flash[:html_safe] = true
        else
          flash[:error] += " Please contact your instructor."
        end
      when :tango_open
        flash[:error] = "There was an error submitting your autograding job. We are likely down for maintenance if issues persist, please contact #{Rails.configuration.school['support_email']}"
      when :tango_upload
        flash[:error] = "There was an error uploading the submission file."
      when :tango_add_job
        flash[:error] = "Submission was rejected by autograder."
        if @cud.instructor?
          link = (view_context.link_to "Autograder Settings", [:edit, course, assessment, :autograder])
          flash[:error] += " Verify the autograding properties at #{link}.<br>ErrorMsg: " + e.additional_data
          flash[:html_safe] = true
        end
      when :missing_autograder_file
        flash[:error] = "One or more files are missing in the server. Please contact the instructor. The missing files are: " + e.additional_data
      else
        flash[:error] = "Autograding failed because of an unexpected exception in the system."
      end

      raise e # pass it on
    end

    link = "<a href=\"#{url_for(controller: 'jobs', action: 'getjob', id: job)}\">Job ID = #{job}</a>"
    viewFeedbackLink = "<a href=\"#{url_for(controller: 'assessments', action: 'viewFeedback', submission_id: submissions[0].id, feedback: assessment.problems[0].id)}\">View autograding progress.</a>"
    flash[:success] = ("Submitted file #{submissions[0].filename} (#{link}) for autograding." \
      " #{viewFeedbackLink}")
    flash[:html_safe] = true
    job
  end

end
