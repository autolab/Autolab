module AssessmentAutograde
  require 'autoConfig'


  # Initialize the module-specific key-value store
  def moduleInstallAutograde
    UserModule.create(:name=>"Autograde",:course_id=>@assessment.id)
    um = UserModule.load("Autograde",@assessment.id)
    um.addColumn("dave_key",String)
    um.addColumn("dave_user",String)
  end

  #
  # autogradeAfterHandin - submits an autograding job to Tango when
  # the students submit their work.
  #
  def autogradeAfterHandin(submission)
    # Check for nil first, since students should know about this
    if submission.nil? then
      flash[:error] = "Submission could not be autograded due to " +
        "an error in creation"
      return
    elsif ! autograde?(submission) then
      return # not an error- we specified this behavior!
    end

    @submission = submission
    @assessment = submission.assessment
    job = createVm()
    if job == -2 then
      flash[:error] = "Autograding failed because there are no autograding properties."
      if @cud.instructor? then
        link = "<a href=\"#{url_for(:action=>'adminAutograde')}\">Admin Autograding</a>"
        flash[:error] += " Visit #{link} to set the autograding properties."
      else
        flash[:error] += " Please contact your instructor."
      end
    elsif job == -1 then
      flash[:error] = "There was an error (#{job}) submitting your autograding job. " +
        "Please contact your instructor."
    else
      link = "<a href=\"#{url_for(:controller=>'jobs')}\">Job ID = #{job}</a>"
      flash[:success] = ("Submitted file #{@submission.filename} (#{link}) for autograding." +
        " Refresh the page to see the results.").html_safe
    end
  end

#
  # createVM - this scary-looking function initiates an autograding
  # job request on the backend. It builds a job structure that
  # contains various info about the job, send submits it to the
  # Tango server via an addJob() Thrift RPC call.
  #
  def createVm
    extend_config_module()

    assessmentDir = File.join(AUTOCONFIG_COURSE_DIR,@course.name,@assessment.name)

    # Send OPEN api request to create course-lab directory.
    openReqURL = "http://#{RESTFUL_HOST}:#{RESTFUL_PORT}/open/#{RESTFUL_KEY}/#{RESTFUL_COURSELAB}/"
    COURSE_LOGGER.log("Req: " + openReqURL)
    openResponse = Net::HTTP.get_response(URI.parse(openReqURL))
    openResponseJSON = JSON.parse(openResponse.body)
    if (openResponseJSON.nil? || openResponseJSON["statusId"] < 0) then
      return -1
    end
    existingFileList = openResponseJSON["files"]
    print "\n\n"
    print existingFileList
    print "\n\n"

    COURSE_LOGGER.log("Existing File List: #{existingFileList.to_s}")

    # Send UPLOAD api request to upload autograde files.
    uploadHTTPReq = Net::HTTP.new(RESTFUL_HOST, RESTFUL_PORT)
    begin
      COURSE_LOGGER.log("Dir: #{assessmentDir}")

      if @assessment.config_module.instance_methods.include?(:autogradeInputFiles) then
        uploadFileList =  @assessment.config_module.autogradeInputFiles(assessmentDir)
      else
        uploadFileList =  autogradeInputFiles(assessmentDir)
        print "\n\n"
        print uploadFileList
        print "\n\n"

      end

      COURSE_LOGGER.log("Upload File List: #{uploadFileList.to_s}")
    rescue Exception => e
      print e
      COURSE_LOGGER.log("Error with getting files: " + e.to_s)
      e.backtrace.each { |line| COURSE_LOGGER.log(line) }
      return -3
    end


    uploadFileList.each { |f|

      print "\n"
      print f["localFile"]
      print "\n"

      md5hash = Digest::MD5.file(f["localFile"]).to_s

      print "\n"
      print md5hash
      print "\n"
      unless existingFileList.include?(md5hash)
        uploadReq = Net::HTTP::Post.new("/upload/#{RESTFUL_KEY}/#{RESTFUL_COURSELAB}/")
	      uploadReq.add_field("Filename", f["destFile"])
        begin
          file = File.open(f["localFile"], "rb")
          uploadReq.body = file.read
        rescue Exception
          return -4
        ensure
          file.close unless file.nil?
        end
        uploadResponse = uploadHTTPReq.request(uploadReq)
        COURSE_LOGGER.log("Req: "+ "/upload/#{RESTFUL_KEY}/#{RESTFUL_COURSELAB}/");
	uploadResponseJSON = JSON.parse(uploadResponse.body)
        if (uploadResponseJSON.nil? || uploadResponseJSON["statusId"] < 0) then
          return -6
        end
      end
    }

    # Get the autograding properties for this assessment.
    @autograde_prop = AutogradingSetup.where(:assessment_id => @assessment.id).first
    if !@autograde_prop then
      return -2
    end

    File.join(AUTOCONFIG_COURSE_DIR,@course.name,@assessment.name)

    filename = @submission.course_user_datum.email + "_" +
      @submission.version.to_s + "_" +
      @assessment.name + "_" +
      "autograde.txt"
    feedbackFile = File.join(assessmentDir, @assessment.handin_directory, filename)

    COURSE_LOGGER.log("Feedbackfile:" + feedbackFile)

    # Generate the dave number/string, this is used when autograding is
    # done.  The key is not guaranteed to be unique, we just hope to God
    # it is.
    dave = (0...60).map{65.+(rand(25)).chr}.join
    daveNum = rand(2000000000)

    callBackURL = request.base_url +
      "/courses/#{@course.id}/assessments/#{@assessment.id}/submissions/#{@submission.id}/" +
      "autograde_done?dave=#{dave}"

    COURSE_LOGGER.log("Callback: #{callBackURL}")

    jobName = @course.name + "_" +
      @assessment.name + "_" +
      @submission.version.to_s + "_" +
      @submission.course_user_datum.email


    # Send ADDJOB api request to add autograde job to queue.
    addJobHTTPReq = Net::HTTP.new(RESTFUL_HOST, RESTFUL_PORT)
    addJobReq = Net::HTTP::Post.new("/addJob/#{RESTFUL_KEY}/#{RESTFUL_COURSELAB}/")
    addJobReq.body = {"image" => @autograde_prop.autograde_image,
                      "files" => uploadFileList.map{|f| Pathname.new(f["destFile"]).basename.to_s},
                      "output_file" => filename,
                      "timeout" => @autograde_prop.autograde_timeout,
                      "callback_url" => callBackURL,
                      "jobName" => jobName }.to_json


    list = uploadFileList.map{|f| Pathname.new(f["destFile"]).basename.to_s}
    COURSE_LOGGER.log("Files: #{list.to_s}")
    COURSE_LOGGER.log("Req: "+ "/addJob/#{RESTFUL_KEY}/#{RESTFUL_COURSELAB}/")
    addJobResponse = addJobHTTPReq.request(addJobReq)
    addJobResponseJSON = JSON.parse(addJobResponse.body)
    autogradeModule = UserModule.load("Autograde",@assessment.id)
    if (autogradeModule == nil) then
      moduleInstallAutograde()
      autogradeModule = UserModule.load("Autograde",@assessment.id)
    end
    autogradeModule.put("dave_key",daveNum,dave)

    subName = "#{@submission.course_user_datum.email}-#{@submission.version}"
    autogradeModule.put("dave_user",daveNum,subName)

    # Sanity check that job has been added successfully.
    if addJobResponseJSON.nil? || addJobResponseJSON["statusId"] < 0 then
      return -9
    end

    # If user opt not to use a call back URL, we pull the job for 50 seconds.
    # Otherwise, nothing needs to be done here.
    if callBackURL.nil? || callBackURL.empty? then
      begin
        feedback = Timeout::timeout(80) {
          while true do
            pollReqURL = "http://#{RESTFUL_HOST}:#{RESTFUL_PORT}/poll/#{RESTFUL_KEY}/#{RESTFUL_COURSELAB}/#{filename}/"
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
        autogradeDone(dave, @submission, feedback)
      end
    end #if no callback url

    return addJobResponseJSON["jobId"]
  end

  #
  # autogradeInputFiles - Specifies the input files for the autograder.
  # Can be overridden in the lab config file.
  #
  def autogradeInputFiles(assessmentDir)
    # Absolute path names on the local autolab server of the input
    # autograding input files: 1) The student's handin file, 2)
    # The makefile that runs the process, 3) The tarfile with all
    # of files needed by the autograder. Can be overridden in the
    # lab config file.
    localHandin = File.join(assessmentDir, @assessment.handin_directory,
                            @submission.filename)
    localMakefile = File.join(assessmentDir, "autograde-Makefile")
    localAutograde = File.join(assessmentDir, "autograde.tar")

    # Name of the handin file on the destination machine
    destHandin = @assessment.handin_filename

    # Construct the array of input files.
    handin = {"localFile" => localHandin, "destFile" => destHandin}
    makefile = {"localFile" => localMakefile, "destFile" => "Makefile"}
    autograde = {"localFile" => localAutograde, "destFile" => "autograde.tar"}

    return [handin, makefile, autograde]
  end

  # Specifies conditions under which an assignment should be autograded
  def autograde?(submission)
    not (submission.nil? or submission.handinFile().nil?)
  end

end
