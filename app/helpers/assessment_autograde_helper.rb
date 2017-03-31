module AssessmentAutogradeHelper

  class AutogradeError < StandardError
    attr_reader :error_code
    attr_reader :additional_data # additional error data
    
    def initialize(msg = "Autograding Failed", error_code = :unexpected, additional_data = "")
      @error_code = error_code
      @additional_data = additional_data
      super(msg)
    end
  end

  ##
  # sends an upload request for every file that needs to be uploaded.
  # returns a list of files uploaded
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
      raise AutogradeError.new("Error with getting files", :tango_upload, e.message)
    end
    
    upload_file_list.each do |f|
      if !Pathname.new(f["localFile"]).file?
        raise AutogradeError.new("Error while uploading autograding files", :missing_autograder_file)
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
        raise AutogradeError.new("Error while uploading autograding files", :tango_upload, e.message)
      end
    end

    upload_file_list
  end

  ##
  # Generates a dave key, and saves it for each submission.
  # Returns the dave key
  #
  def save_daves(submissions)
    # Generate the dave number/string, this is used when autograding is done.
    # The key is not guaranteed to be unique, but it's gonna be unique.
    dave = (0...60).map { 65.+(rand(25)).chr }.join

    begin
      # save dave keys.  These let us know which submissions to save the autoresult for
      ActiveRecord::Base.transaction do
        submissions.each do |submission|
          submission.dave = dave
          submission.save!
        end
      end
    rescue
      raise AutogradeError.new("Error saving daves", :save_daves)
    end

    dave
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
  # Returns the Tango response
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
      raise AutogradeError.new("Error while adding job to the queue", :tango_add_job, e.message)
    end

    response
  end

  ##
  # Polls Tango every 3 seconds until the autograding job is done.
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
      raise AutogradeError.new("Timed out while polling Tango", :tango_poll)
    rescue TangoClient::TangoException => e
      raise AutogradeError.new("Error while polling for job status", :tango_poll, e.message)
    end

    if feedback.nil?
      raise AutogradeError.new("Error getting response from polling Tango", :tango_poll)
    else
      if assessment.overwrites_method?(:autogradeDone)
        assessment.config_module.autogradeDone(submissions, feedback)
      else
        # this doesn't work because autogradeDone is defined in submissions_controller
        autogradeDone(submissions, feedback)
      end

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
    raise AutogradeError.new("There are no autograding properties", :missing_autograding_props) unless @autograde_prop

    # send the tango open request
    begin
      existing_files = TangoClient.open("#{course.name}-#{assessment.name}")
    rescue TangoClient::TangoException => e
      COURSE_LOGGER.log("#{e.message}")
      raise AutogradeError.new("Error with open request on Tango", :tango_open, e.message)
    end

    # send the tango upload requests
    upload_file_list = tango_upload(course, assessment, submissions[0], existing_files)

    dave = save_daves(submissions)

    output_file = get_output_file(assessment, submissions[0])
    callback_url = get_callback_url(course, assessment, submissions[0], dave)
    job_name = get_job_name(course, assessment, submissions[0])

    response_json = tango_add_job(course, assessment, upload_file_list,
                                          callback_url, job_name, output_file)

    # If autolab user opts not to use a callback URL, we poll the job for 80 seconds
    if callback_url.blank?
      tango_poll(course, assessment, submissions, output_file)
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
      File.open(feedback_file, "w") do |f|
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
      raise AutogradeError.new("The Autograder returned no output", :autograde_no_output) if lines.nil?

      # The last line of the output is assumed to be the
      # autoresult string from the autograding driver
      autoresult = lines[lines.length - 1].chomp

      if @assessment.overwrites_method?(:parseAutoresult)
        scores = @assessment.config_module.parseAutoresult(autoresult, true)
      else
        scores = parseAutoresult(autoresult, true)
      end
      raise AutogradeError.new("Empty autoresult string", :empty_autoresult) if scores.keys.length == 0

      # Grab the autograde config info
      @autograde_prop = @assessment.autograder

      # Record each of the scores extracted from the autoresult
      scores.keys.each do |key|
        problem = @assessment.problems.find_by(name: key)
        raise AutogradeError.new("Problem \"" + key + "\" not found.") unless problem
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
    raise AutogradeError.new("Empty autoresult", :parse_autoresult) unless parsed
    raise AutogradeError.new("Missing 'scores' object in the autoresult", :parse_autoresult) unless parsed["scores"]
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

      raise AutogradeError.new("Assessment #{ass_name} does not exist!", :nonexistent_assessment) unless @assessment

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
    COURSE_LOGGER.log(error.backtrace)
    raise error
  end

end