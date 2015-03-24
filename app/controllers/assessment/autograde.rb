module AssessmentAutograde
  require "uri"
  require_relative Rails.root.join("config", "autogradeConfig.rb")

  # method called when Tango returns the output
  # action_no_auth :autograde_done
  def autograde_done
    @course = Course.find_by_name(params[:course_id]) or (render(nothing: true) && return)
    @assessment = @course.assessments.find_by_name(params[:id])
    unless @assessment && @assessment.has_autograde
      render(nothing: true) && return
    end
    # there can be multiple submission with the same dave if this was a group submission
    submissions = Submission.where(dave: params[:dave]).all

    feedback_str = params[:file].read

    COURSE_LOGGER.setCourse(@course)
    COURSE_LOGGER.log("autograde_done")
    COURSE_LOGGER.log("autograde_done hit: #{request.fullpath}")

    begin
      extend_config_module(@assessment, submissions[0], @cud)
    rescue Exception => e
      COURSE_LOGGER.log("Error extend config")
      COURSE_LOGGER.log(e)
    end

    require_relative(Rails.root.join("assessmentConfig", "#{@course.name}-#{@assessment.name}.rb"))

    assign = @assessment.name.gsub(/\./, "")

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
    @submission = Submission.find(params[:submission_id])
    @effectiveCud = @submission.course_user_datum
    @course = @submission.course_user_datum.course
    @assessment = @submission.assessment

    unless @assessment.has_autograde
      # Not an error, this behavior was specified!
      flash[:info] = "This submission is not autogradable"
      redirect_to(history_course_assessment_path(@course, @assessment, cud_id: @effectiveCud.id)) && return
    end

    autogradeSubmissions(@course, @assessment, [@submission])

    redirect_to(history_course_assessment_path(@course, @assessment, cud_id: @effectiveCud.id)) && return
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

    if failed_jobs > 0
      flash[:error] = "Warning: Could not regrade #{failed_jobs} submission(s):<br>" + failed_list
    end
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
    @submissions = @assessment.submissions.where(special_type: Submission::NORMAL).order("version DESC")

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

    if failed_jobs > 0
      flash[:error] = "Warning: Could not regrade #{failed_jobs} submission(s):<br>" + failed_list
    end
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
    if submissions.blank?
      flash[:error] = "Submission could not be autograded due to an error in creation"
      return
    end

    job = sendJob(course, assessment, submissions, @cud)
    if job == -2
      flash[:error] = "Autograding failed because there are no autograding properties."
      if @cud.instructor?
        link = "<a href=\"#{url_for(action: 'adminAutograde')}\">Admin Autograding</a>"
        flash[:error] += " Visit #{link} to set the autograding properties."
      else
        flash[:error] += " Please contact your instructor."
      end
    elsif job == -1
      link = "<a href=\"#{url_for(controller: 'jobs')}\">Jobs</a>"
      flash[:error] = "There was an error submitting your autograding job. " \
          "Check the #{link} page for more info."
    elsif job == -3 || job == -4 || job == -6
      flash[:error] = "There was an error uploading the submission file. (Error #{job})"
    elsif job == -9
      flash[:error] = "Submission was rejected by autograder."
      if @cud.instructor?
        link = "<a href=\"#{url_for(action: 'adminAutograde')}\">Admin Autograding</a>"
        flash[:error] += " (Verify the autograding properties at #{link}.)"
      end
    elsif job < 0
      flash[:error] = "Autograding failed because of an unexpected exception in the system."
    else
      link = "<a href=\"#{url_for(controller: 'jobs', action: 'getjob', id: job)}\">Job ID = #{job}</a>"
      flash[:success] = ("Submitted file #{submissions[0].filename} (#{link}) for autograding." \
        " Refresh the page to see the results.").html_safe
    end
    job
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
    assessmentDir = File.join(AUTOCONFIG_COURSE_DIR, course.name, assessment.name)

    # Send OPEN api request to create/query course-lab directory.
    openReqURL = "http://#{RESTFUL_HOST}:#{RESTFUL_PORT}/open/#{RESTFUL_KEY}/#{course.name}-#{assessment.name}/"
    COURSE_LOGGER.log("Req: " + openReqURL)
    openResponse = Net::HTTP.get_response(URI.parse(openReqURL))
    openResponseJSON = JSON.parse(openResponse.body)
    if openResponseJSON.nil? || openResponseJSON["statusId"] < 0
      return -1
    end
    existingFileList = openResponseJSON["files"]
    COURSE_LOGGER.log("Existing File List: #{existingFileList}")

    # Send UPLOAD api request to upload autograde files.
    uploadHTTPReq = Net::HTTP.new(RESTFUL_HOST, RESTFUL_PORT)
    begin
      COURSE_LOGGER.log("Dir: #{assessmentDir}")

      if assessment.overwrites_method?(:autogradeInputFiles)
        uploadFileList =  assessment.config_module.autogradeInputFiles(assessmentDir)
      else
        uploadFileList =  autogradeInputFiles(assessmentDir, assessment, submissions[0])
      end

      COURSE_LOGGER.log("Upload File List: #{uploadFileList}")
    rescue Exception => e
      COURSE_LOGGER.log("Error with getting files: " + e.to_s)
      e.backtrace.each { |line| COURSE_LOGGER.log(line) }
      return -3
    end

    uploadFileList.each do |f|
      md5hash = Digest::MD5.file(f["localFile"]).to_s
      unless existingFileList.any? { |h| h["md5"] == md5hash && h["localFile"] == File.basename(f["localFile"]) }
        uploadReq = Net::HTTP::Post.new("/upload/#{RESTFUL_KEY}/#{course.name}-#{assessment.name}/")
        uploadReq.add_field("Filename", File.basename(f["localFile"]))
        begin
          file = File.open(f["localFile"], "rb")
          uploadReq.body = file.read
        rescue Exception
          return -4
        ensure
          file.close unless file.nil?
        end
        uploadResponse = uploadHTTPReq.request(uploadReq)
        COURSE_LOGGER.log("Req: " + "/upload/#{RESTFUL_KEY}/#{course.name}-#{assessment.name}/")
        uploadResponseJSON = JSON.parse(uploadResponse.body)
        if uploadResponseJSON.nil? || uploadResponseJSON["statusId"] < 0
          return -6
        end
      end
    end

    # Get the autograding properties for this assessment.
    @autograde_prop = AutogradingSetup.find_by(assessment_id: assessment.id)
    unless @autograde_prop
      return -2
    end

    filename = "%s_%d_%s_autograde.txt" % [submissions[0].course_user_datum.email, submissions[0].version, assessment.name]
    feedbackFile = File.join(assessmentDir, assessment.handin_directory, filename)

    COURSE_LOGGER.log("Feedbackfile:" + feedbackFile)

    # Generate the dave number/string, this is used when autograding is
    # done.  The key is not guaranteed to be unique, we just hope to God
    # it is.
    dave = (0...60).map { 65.+(rand(25)).chr }.join

    # save dave keys.  These let us know which submissions to save the autoresult for
    ActiveRecord::Base.transaction do
      submissions.each do |submission|
        submission.dave = dave
        submission.save!
      end
    end

    begin
      hostname = request.base_url
    rescue Exception => e
      hostname = `hostname`
      hostname = "https://" + hostname.strip
    end

    callBackURL = if RESTFUL_USE_POLLING
                    ""
                  else
                    "#{hostname}/courses/#{course.id}/assessments/#{assessment.id}/autograde_done?dave=#{dave}&submission_id=#{submissions[0].id}"
    end

    COURSE_LOGGER.log("Callback: #{callBackURL}")

    jobName = "%s_%s_%d_%s" % [course.name, assessment.name, submissions[0].version, submissions[0].course_user_datum.email]

    # Send ADDJOB api request to add autograde job to queue.
    addJobHTTPReq = Net::HTTP.new(RESTFUL_HOST, RESTFUL_PORT)
    addJobReq = Net::HTTP::Post.new("/addJob/#{RESTFUL_KEY}/#{course.name}-#{assessment.name}/")
    addJobReq.body = { "image" => @autograde_prop.autograde_image,
                       "files" => uploadFileList.map do|f|
                         { "localFile" => File.basename(f["localFile"]),
                           "destFile" => Pathname.new(f["destFile"]).basename.to_s }
                       end,
                       "output_file" => filename,
                       "timeout" => @autograde_prop.autograde_timeout,
                       "callback_url" => callBackURL,
                       "jobName" => jobName }.to_json

    list = uploadFileList.map { |f| Pathname.new(f["destFile"]).basename.to_s }
    COURSE_LOGGER.log("Files: #{list}")
    COURSE_LOGGER.log("Req: " + "/addJob/#{RESTFUL_KEY}/#{course.name}-#{assessment.name}/")
    addJobResponse = addJobHTTPReq.request(addJobReq)
    addJobResponseJSON = JSON.parse(addJobResponse.body)

    # Sanity check that job has been added successfully.
    if addJobResponseJSON.nil? || addJobResponseJSON["statusId"] < 0
      return -9
    end

    # If user opt not to use a call back URL, we pull the job for 50 seconds.
    # Otherwise, nothing needs to be done here.
    if callBackURL.blank?
      begin
        feedback = Timeout.timeout(80) do
          loop do
            pollReqURL = "http://#{RESTFUL_HOST}:#{RESTFUL_PORT}/poll/#{RESTFUL_KEY}/#{course.name}-#{assessment.name}/#{URI.encode(filename)}/"
            pollResponse = Net::HTTP.get_response(URI.parse(pollReqURL))
            if pollResponse.content_type == "application/json"
              pollResponseStatusId = JSON.parse(pollResponse.body)["statusId"]
            else
              feedback = pollResponse.body
              break
            end
            sleep 3
          end
          feedback = feedback
        end
      rescue Timeout::Error
        return -11 # pollResponseStatusId
      end
      if feedback.nil?
        return -12 # pollResponseStatusId
      else
        if assessment.overwrites_method?(:autogradeDone)
          assessment.config_module.autogradeDone(submissions, feedback)
        else
          # this doesn't work because autogradeDone is defined in submissions_controller
          autogradeDone(submissions, feedback)
        end
      end
    end # if no callback url

    addJobResponseJSON["jobId"]
  end

  #
  # autogradeInputFiles - Specifies the input files for the autograder.
  # Can be overridden in the lab config file.
  #
  def autogradeInputFiles(assessmentDir, assessment, submission)
    # Absolute path names on the local autolab server of the input
    # autograding input files: 1) The student's handin file, 2)
    # The makefile that runs the process, 3) The tarfile with all
    # of files needed by the autograder. Can be overridden in the
    # lab config file.
    localHandin = File.join(assessmentDir, assessment.handin_directory,
                            submission.filename)
    localMakefile = File.join(assessmentDir, "autograde-Makefile")
    localAutograde = File.join(assessmentDir, "autograde.tar")

    # Name of the handin file on the destination machine
    destHandin = assessment.handin_filename

    # Construct the array of input files.
    handin = { "localFile" => localHandin, "destFile" => destHandin }
    makefile = { "localFile" => localMakefile, "destFile" => "Makefile" }
    autograde = { "localFile" => localAutograde, "destFile" => "autograde.tar" }

    [handin, makefile, autograde]
  end

  ##
  # autogradeDone - called when autograding is done, either by the submissions#autograde_done
  # route getting called by Tango or by the Autograde module polling Tango. In either case,
  # submission is confirmed via dave key to have been created by Autolab
  #
  def autogradeDone(submissions, feedback)
    assessmentDir = File.join(AUTOCONFIG_COURSE_DIR, @course.name, @assessment.name)

    submissions.each do |submission|
      filename = "%s_%d_%s_autograde.txt" % [submission.course_user_datum.email, submission.version, @assessment.name]

      feedbackFile = File.join(assessmentDir, @assessment.handin_directory, filename)
      COURSE_LOGGER.log("Looking for Feedbackfile:" + feedbackFile)

      begin
        f = File.open(feedbackFile, "w")
        f.write(feedback)
      ensure
        f.close unless f.nil?
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
      if lines.nil?
        fail "The Autograder returned no output. \n"
      end

      # The last line of the output is assumed to be the
      # autoresult string from the autograding driver
      autoresult = lines[lines.length - 1].chomp

      if @assessment.overwrites_method?(:parseAutoresult)
        scores = @assessment.config_module.parseAutoresult(autoresult, true)
      else
        scores = parseAutoresult(autoresult, true)
      end

      if scores.keys.length == 0
        fail "Empty autoresult string."
      end

      # Grab the autograde config info
      @autograde_prop = AutogradingSetup.find_by(assessment_id: @assessment.id)

      # Record each of the scores extracted from the autoresult
      for key in scores.keys do
        problem = @assessment.problems.find_by(name: key)
        unless problem
          fail "Problem \"" + key + "\" not found."
        end
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
    rescue Exception => e
      feedback_str = "An error occurred while parsing the autoresult returned by the Autograder.\n\nError message: " + e.to_s + "\n\n"
      if lines && (lines.length < 10_000)
        feedback_str += lines.join
      end
      @assessment.problems.each do |p|
        submissions.each do |submission|
          score = submission.scores.find_or_initialize_by(problem_id: p.id)
          if score.new_record? # don't overwrite scores
            score.score = 0
            score.feedback = feedback_str
            score.released = true
            score.grader_id = 0
            score.save!
          end
        end
      end
    end

    logger = Logger.new(Rails.root.join("courses", @course.name, @assessment.name, "log.txt"))
    submissions.each do |submission|
      logger.add(Logger::INFO) { "#{submission.course_user_datum.email}, #{submission.version}, #{autoresult}" }
    end
  end

  ##
  # parseAutoresult - Extracts the problem scores from a JSON
  # autoresult string. If anything goes wrong, raise an exception
  # with the caller. Can be overridden in the lab config file.
  #
  def parseAutoresult(autoresult, _isOfficial)
    parsed = ActiveSupport::JSON.decode(autoresult.gsub(/([a-zA-Z0-9]+):/, '"\1":'))
    unless parsed
      fail "Empty autoresult"
    end
    unless parsed["scores"]
      fail "Missing 'scores' object in the autoresult"
    end
    parsed["scores"]
  end

  def extend_config_module(assessment, submission, cud)
    require assessment.config_file_path

    # casted to local variable so that
    # they can be passed into `module_eval`
    methods = assessment.config_module.instance_methods
    assignName = assessment.name
    course = assessment.course

    begin
      req_hostname = request.host
    rescue Exception => e
      req_hostname = "n/a"
    end

    begin
      req_port = request.port
    rescue Exception => e
      req_port = 80
    end

    assessment.config_module.module_eval do
      # we cast these values into module variables
      # so that they can be accessible inside module
      # methods
      @cud = cud
      @course = course
      @assessment = course.assessments.find_by(name: assignName)
      @hostname = req_hostname
      @port = req_port
      @submission = submission

      unless @assessment
        fail "Assessment #{assignName} does not exist!"
      end

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

  rescue Exception => error
    COURSE_LOGGER.log(error)
    COURSE_LOGGER.log(error.backtrace)

    if @cud && @cud.has_auth_level?(:instructor)
      redirect_to(action: :reload) && return
    else
      redirect_to(home_error_path) && return
    end
  end
end
