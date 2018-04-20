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
    ASSESSMENT_LOGGER.setAssessment(@assessment)

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
          failed_list += "#{submission.filename}: autograding error.<br>"
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
          failed_list += "#{submission.filename}: autograding error.<br>"
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
    if job < 0
      COURSE_LOGGER.log("SendJob failed for #{submissions[0].id}: code #{job}")
      COURSE_LOGGER.log("SendJob user error message #{flash[:error]}")
    end
    job
  end

  ##
  # sends an upload request for every file that needs to be uploaded.
  # returns a list of files uploaded on success and a negative number on failure
  #
  def tango_upload(course, assessment, submission, existing_files)
    # first, figure out which files need to get sent
    ass_dir = assessment.folder_path
    begin
      COURSE_LOGGER.log("Dir: #{ass_dir}")

      if assessment.overwrites_method?(:autogradeInputFiles)
        upload_file_list = assessment.config_module.autogradeInputFiles(ass_dir)
      else
        upload_file_list = autogradeInputFiles(ass_dir, assessment, submission)
      end

      COURSE_LOGGER.log("Upload File List: #{upload_file_list}")
    rescue StandardError => e
      COURSE_LOGGER.log("Error with getting files: #{e}")
      e.backtrace.each { |line| COURSE_LOGGER.log(line) }
      return -3, nil
    end
    
		upload_file_list.each do |f|
			if !Pathname.new(f["localFile"]).file?
        flash[:error] = "Error while uploading autograding files."
				return -10, nil
			end
		end

		# now actually send all of the upload requests
    upload_file_list.each do |f|
			md5hash = Digest::MD5.file(f["localFile"]).to_s
      next if (existing_files.has_key?(File.basename(f["localFile"])) &&
          existing_files[File.basename(f["localFile"])] == md5hash)

      begin
        TangoClient.upload("#{course.name}-#{assessment.name}",
                           File.basename(f["localFile"]),
                           File.open(f["localFile"], "rb").read)
      rescue TangoClient::TangoException => e
        flash[:error] = "Error while uploading autograding files: #{e.message}"
        COURSE_LOGGER.log("Error while uploading autograding files for #{submission.id}: #{e.message}")
        return -4, nil
      end
    end

    [0, upload_file_list]
  end

  ##
  # Generates a dave key, and saves it for each submission.
  # Returns 0 on success and -13 on failure
  #
  def save_daves(submissions)
    # Generate the dave number/string, this is used when autograding is done.
    # The key is not guaranteed to be unique, but it's gonna be unique.
    dave = (0...60).map { 65.+(rand(25)).chr }.join
    failed = false
    # save dave keys.  These let us know which submissions to save the autoresult for
    ActiveRecord::Base.transaction do
      submissions.each do |submission|
        submission.dave = dave
        if not submission.save
           COURSE_LOGGER.log("Error while updating submission #{submission.id} callback key:")
           submission.errors.full_messages.each do |msg|
              COURSE_LOGGER.log("   (#{submission.id}): #{msg}")
           end
           failed = true
        end
      end
    end
    if failed
      return -13, nil
    end

    [0, dave]
  end

  def get_output_file(assessment, submission)
    "#{submission.course_user_datum.email}_#{submission.version}_#{assessment.name}_autograde.txt"
  end

  ##
  # Returns the callback_url for the given submission/dave key
  #
  def get_callback_url(course, assessment, submission, dave)
    begin
      if Rails.env.development?
        hostname = request.base_url
      else
        hostname = "https://" + request.host
      end
    rescue
      hostname = `hostname`
      hostname = "https://" + hostname.strip
    end

    callback_url = (RESTFUL_USE_POLLING) ? "" :
      "#{hostname}/courses/#{course.name}/assessments/#{assessment.name}/autograde_done?dave=#{dave}&submission_id=#{submission.id}"
    COURSE_LOGGER.log("Callback: #{callback_url}")

    callback_url
  end

  ##
  # Returns the job name for the given submission
  #
  def get_job_name(course, assessment, submission)
    "#{course.name}_#{assessment.name}_#{submission.version}_#{submission.course_user_datum.email}"
  end

  ##
  # Makes the Tango addJob request.
  # Returns 0 on success and -9 on failure.
  #
  def tango_add_job(course, assessment, upload_file_list, callback_url, job_name, output_file)
    job_properties = { "image" => @autograde_prop.autograde_image,
                       "files" => upload_file_list.map do |f|
                         { "localFile" => File.basename(f["localFile"]),
                           "destFile" => Pathname.new(f["destFile"]).basename.to_s }
                       end,
                       "output_file" => output_file,
                       "timeout" => @autograde_prop.autograde_timeout,
                       "callback_url" => callback_url,
                       "jobName" => job_name }.to_json
    begin
      response = TangoClient.addjob("#{course.name}-#{assessment.name}", job_properties)
    rescue TangoClient::TangoException => e
      flash[:error] = "Error while adding job to the queue: #{e.message}"
      COURSE_LOGGER.log("Error while adding job to the queue: #{e.message}")
      return -9, nil
    end
    [0, response]
  end

  ##
  # Polls Tango every 3 seconds until the autograding job is done.
  # Returns 0 on success and a negative number if there is an error
  #
  def tango_poll(course, assessment, submissions, output_file)
    feedback = nil
    begin
      Timeout.timeout(80) do
        loop do
          response = TangoClient.poll("#{course.name}-#{assessment.name}", "#{URI.encode(output_file)}")
          # json is returned when a job is not complete
          unless response.content_type == "application/json"
            feedback = response.body
            break
          end
          sleep 3
        end
      end
    rescue Timeout::Error
      COURSE_LOGGER.log("Error while polling for #{submissions[0].id} job status: Timeout")
      return -11
    rescue TangoClient::TangoException => e
      flash[:error] = "Error while polling for job status: #{e.message}"
      COURSE_LOGGER.log("Error while polling for #{submissions[0].id} job status: #{e.message}")
      return -11
    end

    if feedback.nil?
      return -12
      COURSE_LOGGER.log("Error while polling for #{submissions[0].id} job status: No feedback")
    else
      if assessment.overwrites_method?(:autogradeDone)
        assessment.config_module.autogradeDone(submissions, feedback)
      else
        # this doesn't work because autogradeDone is defined in submissions_controller
        autogradeDone(submissions, feedback)
      end

      return 0
    end
  end

  ##
  # sendJob - this scary-looking function initiates an autograding
  # job request on the backend. It builds a job structure that
  # contains various info about the job, send submits it to the
  # Tango server via an REST API.
  #
  # submissions must have at least one element
  #
  def sendJob(course, assessment, submissions, cud)
    extend_config_module(assessment, submissions[0], cud)

    # Get the autograding properties for this assessment.
    @autograde_prop = assessment.autograder
    return -2 unless @autograde_prop

    # send the tango open request
    begin
      existing_files = TangoClient.open("#{course.name}-#{assessment.name}")
    rescue TangoClient::TangoException => e
      flash[:error] = "Error with open request on Tango: #{e.message}"
      COURSE_LOGGER.log("Error with open request on Tango for submission #{submissions[0].id}: #{e.message}")
      return -1
    end

    # send the tango upload requests
    status, upload_file_list = tango_upload(course, assessment, submissions[0], existing_files)
    return status if status < 0

    status, dave = save_daves(submissions)
    return status if status < 0

    output_file = get_output_file(assessment, submissions[0])
    callback_url = get_callback_url(course, assessment, submissions[0], dave)
    job_name = get_job_name(course, assessment, submissions[0])

    status, response_json = tango_add_job(course, assessment, upload_file_list,
                                          callback_url, job_name, output_file)
    return status if status < 0

    # If autolab user opts not to use a callback URL, we poll the job for 80 seconds
    if callback_url.blank?
      status = tango_poll(course, assessment, submissions, output_file)
      return status if status < 0
    end

    response_json["jobId"].to_i
  end

  #
  # autogradeInputFiles - Specifies the input files for the autograder.
  # Can be overridden in the lab config file.
  #
  def autogradeInputFiles(ass_dir, assessment, submission)
    # Absolute path names on the local autolab server of the input
    # autograding input files: 1) The student's handin file, 2)
    # The makefile that runs the process, 3) The tarfile with all
    # of files needed by the autograder. Can be overridden in the
    # lab config file.
    local_handin = File.join(ass_dir, assessment.handin_directory, submission.filename)
    local_makefile = File.join(ass_dir, "autograde-Makefile")
    local_autograde = File.join(ass_dir, "autograde.tar")
    local_settings_config = File.join(ass_dir, assessment.handin_directory, submission.filename + ".settings.json")

    # Name of the handin file on the destination machine
    dest_handin = assessment.handin_filename

    # Construct the array of input files.
    handin = { "localFile" => local_handin, "destFile" => dest_handin }
    makefile = { "localFile" => local_makefile, "destFile" => "Makefile" }
    autograde = { "localFile" => local_autograde, "destFile" => "autograde.tar" }
    settings_config = { "localFile" => local_settings_config, "destFile" => "settings.json" }

    if assessment.has_custom_form.to_s == "true"
        [handin, makefile, autograde, settings_config]
    else
        [handin, makefile, autograde]
    end
    
  end

  ##
  # autogradeDone - called when autograding is done, either by the submissions#autograde_done
  # route getting called by Tango or by the Autograde module polling Tango. In either case,
  # submission is confirmed via dave key to have been created by Autolab
  #
  def autogradeDone(submissions, feedback)
    ass_dir = @assessment.folder_path

    submissions.each do |submission|
      filename = submission.autograde_feedback_filename

      feedback_file = File.join(ass_dir, @assessment.handin_directory, filename)
      COURSE_LOGGER.log("Looking for Feedbackfile:" + feedback_file)
      File.open(feedback_file, "wb") do |f|
        f.write(feedback)
      end
    end

    saveAutograde(submissions, feedback)
  end

  ##
  # saveAutograde - parses the autoresult returned by the
  # autograding driver on the backend and updates the scores for
  # each autograded problem. The default autoresult string is in
  # JSON format, but this can be overrriden in the lab.rb file.
  #
  def saveAutograde(submissions, feedback)
    begin
      lines = feedback.lines
      fail "The Autograder returned no output. \n" if lines.nil?

      # The last line of the output is assumed to be the
      # autoresult string from the autograding driver
      autoresult = lines[lines.length - 1].chomp

      if @assessment.overwrites_method?(:parseAutoresult)
        scores = @assessment.config_module.parseAutoresult(autoresult, true)
      else
        scores = parseAutoresult(autoresult, true)
      end
      fail "Empty autoresult string." if scores.keys.length == 0

      # Grab the autograde config info
      @autograde_prop = @assessment.autograder

      # Record each of the scores extracted from the autoresult
      scores.keys.each do |key|
        problem = @assessment.problems.find_by(name: key)
        fail "Problem \"" + key + "\" not found." unless problem
        submissions.each do |submission|
          score = submission.scores.find_or_initialize_by(problem_id: problem.id)
          score.score = scores[key]
          score.feedback = lines.join
          score.released = @autograde_prop.release_score
          score.grader_id = 0
          score.save!
        end
      end

      ActiveRecord::Base.transaction do
        submissions.each do |submission|
          submission.autoresult = autoresult
          submission.dave = nil
          submission.save!
        end
      end
    rescue StandardError => e
      feedback_str = "An error occurred while parsing the autoresult returned by the Autograder.\n
        \nError message: #{e}\n\n"
      feedback_str += lines.join if lines && (lines.length < 10_000)
			@assessment.problems.each do |p|
        submissions.each do |submission|
          score = submission.scores.find_or_initialize_by(problem_id: p.id)
          next unless score.new_record? # don't overwrite scores
          score.score = 0
          score.feedback = feedback_str
          score.released = true
          score.grader_id = 0
          score.save!
        end
      end
    end

    submissions.each do |submission|
      ASSESSMENT_LOGGER.log("#{submission.course_user_datum.email}, #{submission.version}, #{autoresult}")
    end
  end

  ##
  # parseAutoresult - Extracts the problem scores from a JSON
  # autoresult string. If anything goes wrong, raise an exception
  # with the caller. Can be overridden in the lab config file.
  #
  def parseAutoresult(autoresult, _isOfficial)
    parsed = ActiveSupport::JSON.decode(autoresult.gsub(/([a-zA-Z0-9]+):/, '"\1":'))
    fail "Empty autoresult" unless parsed
    fail "Missing 'scores' object in the autoresult" unless parsed["scores"]
    parsed["scores"]
  end

  def extend_config_module(assessment, submission, cud)
    require assessment.config_file_path

    # casted to local variable so that
    # they can be passed into `module_eval`
    methods = assessment.config_module.instance_methods
    ass_name = assessment.name
    course = assessment.course

    begin
      req_hostname = request.host
    rescue
      req_hostname = "n/a"
    end

    begin
      req_port = request.port
    rescue
      req_port = 80
    end

    assessment.config_module.module_eval do
      # we cast these values into module variables
      # so that they can be accessible inside module
      # methods
      @cud = cud
      @course = course
      @assessment = course.assessments.find_by(name: ass_name)
      @hostname = req_hostname
      @port = req_port
      @submission = submission

      fail "Assessment #{ass_name} does not exist!" unless @assessment

      if @assessment.nil?
        flash[:error] = "Error: Invalid assessment"
        redirect_to(home_error_path) && return
      end

      @name = @assessment.name
      @description = @assessment.description
      @start_at = @assessment.start_at
      @due_at = @assessment.due_at
      @end_at = @assessment.end_at
      @visible_at = @assessment.visible_at
      @id = @assessment.id

      # we iterate over all the methods
      # and convert them into `module methods`
      # this makes them available without mixing in the module
      # creating an instance of it.
      # http://www.ruby-doc.org/core-2.1.3/Module.html#method-i-instance_method
      methods.each do |nonmodule_func|
        module_function(nonmodule_func)
        public nonmodule_func
      end
    end

  rescue StandardError => error
    COURSE_LOGGER.log(error)
    error.backtrace.each { |line| COURSE_LOGGER.log(line) }
    raise error
  end
end
