module AssessmentAutograde
  require 'autoConfig.rb'

  ##
  # autogradeSubmissions - submits an autograding job to Tango.
  # Called by assessments#handin, submissions#regrade and submissions#regradeAll
  # returns the job status returned by sendJob
  def autogradeSubmissions(course, assessment, submissions)
    # Check for nil first, since students should know about this
    if submissions.blank? then
      flash[:error] = "Submission could not be autograded due to an error in creation"
      return
    end

    job = sendJob(course, assessment, submissions)
    if job == -3 then # sendJob returned an exception
      flash[:error] = "Autograding failed because of an unexpected exception in the system."
    elsif job == -2 then 
      flash[:error] = "Autograding failed because there are no autograding properties."
      if @cud.instructor? then
        link = "<a href=\"#{url_for(:action=>'adminAutograde')}\">Admin Autograding</a>"
        flash[:error] += " Visit #{link} to set the autograding properties."
      else
        flash[:error] += " Please contact your instructor."
      end
    elsif job == -1 then
      link = "<a href=\"#{url_for(:controller=>'jobs')}\">Jobs</a>"
      flash[:error] = "There was an error submitting your autograding job. " +
        "Check the #{link} page for more info."
    else
      link = "<a href=\"#{url_for(:controller=>"jobs", :action=>"getjob", :id=>job)}\">Job ID = #{job}</a>"
      flash[:success] = ("Submitted file #{submissions[0].filename} (#{link}) for autograding." +
        " Refresh the page to see the results.").html_safe
    end
    return job
  end

  ##
  # sendJob - this scary-looking function initiates an autograding
  # job request on the backend. It builds a job structure that
  # contains various info about the job, send submits it to the
  # Tango server via an REST API.
  #
  # submissions must have at least one element
  #
  def sendJob(course, assessment, submissions)
    extend_config_module_autograde(assessment, submissions[0])
    assessmentDir = File.join(AUTOCONFIG_COURSE_DIR, course.name, assessment.name)

    # Send OPEN api request to create/query course-lab directory.
    openReqURL = "http://#{RESTFUL_HOST}:#{RESTFUL_PORT}/open/#{RESTFUL_KEY}/#{course.name}-#{assessment.name}/"
    COURSE_LOGGER.log("Req: " + openReqURL)
    openResponse = Net::HTTP.get_response(URI.parse(openReqURL))
    openResponseJSON = JSON.parse(openResponse.body)
    if (openResponseJSON.nil? || openResponseJSON["statusId"] < 0) then
      return -1
    end
    existingFileList = openResponseJSON["files"]
    COURSE_LOGGER.log("Existing File List: #{existingFileList.to_s}")

    # Send UPLOAD api request to upload autograde files.
    uploadHTTPReq = Net::HTTP.new(RESTFUL_HOST, RESTFUL_PORT)
    begin
      COURSE_LOGGER.log("Dir: #{assessmentDir}")

      if assessment.overwrites_method?(:autogradeInputFiles) then
        uploadFileList =  assessment.config_module.autogradeInputFiles(assessmentDir)
      else 
        uploadFileList =  autogradeInputFiles(assessmentDir, assessment, submissions[0])
      end

      COURSE_LOGGER.log("Upload File List: #{uploadFileList.to_s}")
    rescue Exception => e
      COURSE_LOGGER.log("Error with getting files: " + e.to_s)
      e.backtrace.each { |line| COURSE_LOGGER.log(line) }
      return -3
    end

    uploadFileList.each do |f|
      md5hash = Digest::MD5.file(f["localFile"]).to_s
      unless existingFileList.any? { |h| h[:md5] == md5hash && h[:localFile] == File.basename(f["localFile"]) }
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
        COURSE_LOGGER.log("Req: "+ "/upload/#{RESTFUL_KEY}/#{course.name}-#{assessment.name}/")
	uploadResponseJSON = JSON.parse(uploadResponse.body)
        if (uploadResponseJSON.nil? || uploadResponseJSON["statusId"] < 0) then 
          return -6
        end
      end
    end

    # Get the autograding properties for this assessment. 
    @autograde_prop = AutogradingSetup.find_by(assessment_id: assessment.id)
    if !@autograde_prop then
      return -2
    end

    filename = "%s_%d_%s_autograde.txt" % [submissions[0].course_user_datum.email, submissions[0].version, assessment.name]
    feedbackFile = File.join(assessmentDir, assessment.handin_directory, filename)

    COURSE_LOGGER.log("Feedbackfile:" + feedbackFile)

    # Generate the dave number/string, this is used when autograding is
    # done.  The key is not guaranteed to be unique, we just hope to God
    # it is. 
    dave = (0...60).map{65.+(rand(25)).chr}.join

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

    callBackURL = hostname +
        "/courses/#{course.id}/assessments/#{assessment.id}/submissions/#{submissions[0].id}/" +
        "autograde_done?dave=#{dave}"

    COURSE_LOGGER.log("Callback: #{callBackURL}") 

    jobName = "%s_%s_%d_%s" % [course.name, assessment.name, submissions[0].version, submissions[0].course_user_datum.email]

    # Send ADDJOB api request to add autograde job to queue.
    addJobHTTPReq = Net::HTTP.new(RESTFUL_HOST, RESTFUL_PORT)
    addJobReq = Net::HTTP::Post.new("/addJob/#{RESTFUL_KEY}/#{course.name}-#{assessment.name}/")
    addJobReq.body = {"image" => @autograde_prop.autograde_image,
                      "files" => uploadFileList.map{|f| {"localFile" => File.basename(f["localFile"]),
                                                         "destFile" => Pathname.new(f["destFile"]).basename.to_s}},
                      "output_file" => filename,
                      "timeout" => @autograde_prop.autograde_timeout,
                      "callback_url" => callBackURL,
                      "jobName" => jobName }.to_json

    list = uploadFileList.map{|f| Pathname.new(f["destFile"]).basename.to_s}
    COURSE_LOGGER.log("Files: #{list.to_s}")
    COURSE_LOGGER.log("Req: "+ "/addJob/#{RESTFUL_KEY}/#{course.name}-#{assessment.name}/")
    addJobResponse = addJobHTTPReq.request(addJobReq)
    addJobResponseJSON = JSON.parse(addJobResponse.body)

    # Sanity check that job has been added successfully.
    if addJobResponseJSON.nil? || addJobResponseJSON["statusId"] < 0 then
      return -9
    end

    # If user opt not to use a call back URL, we pull the job for 50 seconds.
    # Otherwise, nothing needs to be done here.
    if callBackURL.blank? then
      begin
        feedback = Timeout::timeout(80) {
          while true do
            pollReqURL = "http://#{RESTFUL_HOST}:#{RESTFUL_PORT}/poll/#{RESTFUL_KEY}/#{course.name}-#{assessment.name}/#{filename}/"
            pollResponse = Net::HTTP.get_response(URI.parse(pollReqURL))
            if pollResponse.content_type == "application/json" then
              pollResponseStatusId = JSON.parse(pollResponse.body)["statusId"]
            else
              feedback = pollResponse.body 
              break
            end
            sleep 3
          end
          feedback = feedback
        }
      rescue Timeout::Error
        return -11 #pollResponseStatusId
      end
      if feedback.nil? then
        return -19 #pollResponseStatusId
      else
        if assessment.overwrites_method?(:autogradeDone) then
          assessment.config_module.autogradeDone(submissions, feedback)
        else
          # this doesn't work because autogradeDone is defined in submissions_controller
          autogradeDone(submissions, feedback)
        end
      end
    end #if no callback url
    
    return addJobResponseJSON["jobId"]
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
    handin = {"localFile" => localHandin, "destFile" => destHandin}
    makefile = {"localFile" => localMakefile, "destFile" => "Makefile"}
    autograde = {"localFile" => localAutograde, "destFile" => "autograde.tar"}

    return [handin, makefile, autograde]
  end

  def extend_config_module_autograde(assessment, submission)
    begin
      require assessment.config_file_path

      # casted to local variable so that 
      # they can be passed into `module_eval`
      methods = assessment.config_module.instance_methods
      assignName = assessment.name
      course = @course
      cud = @cud

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

        if ! @assessment then
          raise "Assessment #{assignName} does not exist!"
        end

        if @assessment == nil then
          flash[:error] = "Error: Invalid assessment"
          redirect_to home_error_path and return
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

    rescue Exception => @error
      COURSE_LOGGER.log(@error)
      COURSE_LOGGER.log(@error.backtrace)

      if @cud and @cud.has_auth_level? :instructor
        redirect_to action: :reload and return
      else
        redirect_to home_error_path and return
      end
    end
  end
end
