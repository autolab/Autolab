require "uri"
require "tango_client"
require_relative Rails.root.join("config", "autogradeConfig.rb")

module AssessmentAutogradeCore

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
        upload_file_list = assessment.config_module.autogradeInputFiles(ass_dir, assessment, submission)
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
        name_of_file = f["localFile"]
        COURSE_LOGGER.log("Error while uploading autograding files for #{submission.id}: missing file #{name_of_file}")
        raise AutogradeError.new("Error while uploading autograding files", :missing_autograder_file, name_of_file)
      end
      if f["remoteFile"].nil?
        f["remoteFile"] = File.basename(f["localFile"])
      end
    end

    # now actually send all of the upload requests
    upload_file_list.each do |f|
      md5hash = Digest::MD5.file(f["localFile"]).to_s
      next if (existing_files.has_key?(f["remoteFile"]) &&
          existing_files[f["remoteFile"]] == md5hash)

      begin
        TangoClient.upload("#{course.name}-#{assessment.name}",
                           f["remoteFile"],
                           File.open(f["localFile"], "rb").read)
      rescue TangoClient::TangoException => e
        COURSE_LOGGER.log("Error while uploading autograding files for #{submission.id}: #{e.message}")
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

    # save dave keys.  These let us know which submissions to save the autoresult for
    ActiveRecord::Base.transaction do
      submissions.each do |submission|
        submission.dave = dave
        if not submission.save
          error_msg = submission.errors.full_messages.join(", ")
          COURSE_LOGGER.log("Error while updating submission #{submission.id} callback key: #{error_msg}")
          raise AutogradeError.new("Error saving daves", :save_daves, error_msg)
        end
      end
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
    # Use https, unless explicitly specified not to
    prefix = "https://"
    if ENV["DOCKER_SSL"] == "false"
      prefix = "http://"
    end

    begin
      if Rails.env.development?
        hostname = request.base_url
      else
        hostname = prefix + request.host
      end
    rescue
      hostname = `hostname`
      hostname = prefix + hostname.strip
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

  def get_job_status(job_id)
    begin
      raw_live_jobs = TangoClient.jobs
      assigned_jobs, unassigned_jobs = raw_live_jobs.partition {|rjob| rjob["assigned"]}

      # Order by job number to get the position in queue
      unassigned_jobs = unassigned_jobs.sort {|rjob1, rjob2| rjob1["id"].to_i - rjob2["id"].to_i}
    rescue TangoClient::TangoException => e
      COURSE_LOGGER.log("Error while getting jobs")
      raise AutogradeError.new("Error while getting jobs", :get_job_status)
    end
    
    assignment = {"is_assigned"=>assigned_jobs.any? {|rjob| rjob["id"].to_i == job_id}}
    if !assignment["is_assigned"] && unassigned_jobs.length > 0
      # Assign a queue position if the job is live but not assigned
      assignment["queue_position"] = unassigned_jobs.index {|rjob| rjob["id"] == job_id}
      assignment["queue_length"] = unassigned_jobs.length
    end
    assignment
  end

  ##
  # Makes the Tango addJob request.
  # Returns the Tango response
  #
  def tango_add_job(course, assessment, upload_file_list, callback_url, job_name, output_file)
    job_properties = { "image" => @autograde_prop.autograde_image,
                       "files" => upload_file_list.map do |f|
                         { "localFile" => f["remoteFile"],
                           "destFile" => Pathname.new(f["destFile"]).basename.to_s }
                       end,
                       "output_file" => output_file,
                       "timeout" => @autograde_prop.autograde_timeout,
                       "callback_url" => callback_url,
                       "jobName" => job_name,
                       "disable_network" => assessment.disable_network }.to_json
    begin
      response = TangoClient.addjob("#{course.name}-#{assessment.name}", job_properties)
    rescue TangoClient::TangoException => e
      COURSE_LOGGER.log("Error while adding job to the queue: #{e.message}")
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
      COURSE_LOGGER.log("Error while polling for #{submissions[0].id} job status: Timeout")
      raise AutogradeError.new("Timed out while polling Tango", :tango_poll)
    rescue TangoClient::TangoException => e
      COURSE_LOGGER.log("Error while polling for #{submissions[0].id} job status: #{e.message}")
      raise AutogradeError.new("Error while polling for job status", :tango_poll, e.message)
    end

    if feedback.nil?
      COURSE_LOGGER.log("Error while polling for #{submissions[0].id} job status: No feedback")
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

  def tango_get_partial_feedback(job_id)
    begin
      response = TangoClient.getpartialoutput(job_id)
    rescue Timeout::Error
      COURSE_LOGGER.log("Error while getting partial feedback for job #{job_id}")
      raise AutogradeError.new("Timed out while getting partial feedback", :tango_get_partial_feedback)
    rescue TangoClient::TangoException => e
      COURSE_LOGGER.log("Error while getting partial feedback for job #{job_id} status: #{e.message}")
      raise AutogradeError.new("Error while getting partial feedback", :tango_get_partial_feedback, e.message)
    end

    if response.nil?
      COURSE_LOGGER.log("Error while getting partial feedback for job #{job_id} status: No feedback")
      raise AutogradeError.new("Error getting response from getting partial feedback", :tango_get_partial_feedback)
    end

    response["output"]
  end

  ##
  # sendJob_batch - Takes the same parameters as sendJob, except this runs sendJob on all
  # submissions in the submissions list.
  # 
  # Returns a list of failed submissions with their corresponding errors
  #
  def sendJob_batch(course, assessment, submissions, cud)
    failed_list = []

    submissions.each do |submission|
      if submission
        begin
          sendJob(course, assessment, [submission], cud)
        rescue AssessmentAutogradeCore::AutogradeError => e
          if e.error_code == :missing_autograding_props
            # no autograding properties for this assessment
            raise e
          else # autograding failed
            failed_list << {:submission => submission, :error => e}
          end
        end
      else
        failed_list << {:submission => submission, :error => AutogradeError.new("Invalid submission", :nil_submission)}
      end
    end

    return failed_list
  end

  ##
  # sendJob - this scary-looking function initiates an autograding
  # job request on the backend. It builds a job structure that
  # contains various info about the job, send submits it to the
  # Tango server via an REST API.
  #
  # Note on param submissions:
  #   Although this is a list of submissions, it must only contain 
  # submission objects corresponding to the same "logical submission",
  # i.e. this list contains more than one submission ONLY when a
  # student submits a job as a member of a group. In that case, each
  # submission in this list corresponds to a unique submission record,
  # one for each member of the group. Only the first in the list is
  # submitted to tango, but the result is saved to all submissions,
  # as they all have the same "dave".
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
      COURSE_LOGGER.log("Error with open request on Tango for submission #{submissions[0].id}: #{e.message}")
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

    # If Autolab user opts not to use a callback URL, we poll the job for 80 seconds
    if callback_url.blank?
      tango_poll(course, assessment, submissions, output_file)
    end

    job = response_json["jobId"].to_i
    ActiveRecord::Base.transaction do
      submissions.each do |submission|
        submission.update!(jobid: job)
      end
    end
    job
  end

  #
  # autogradeInputFiles - Specifies the input files for the autograder.
  # Can be overridden in the lab config file.
  #
  def autogradeInputFiles(ass_dir, assessment, submission)
    # Absolute path names on the local Autolab server of the input
    # autograding input files: 1) The student's handin file, 2)
    # The makefile that runs the process, 3) The tarfile with all
    # of files needed by the autograder. Can be overridden in the
    # lab config file.
    local_handin = submission.handin_file_path
    remote_handin = submission.handin_file_long_filename
    local_makefile = File.join(ass_dir, "autograde-Makefile")
    local_autograde = File.join(ass_dir, "autograde.tar")

    # Name of the handin file on the destination machine
    dest_handin = assessment.handin_filename

    # Construct the array of input files.
    handin = { "localFile" => local_handin,
               "remoteFile" => remote_handin,
               "destFile" => dest_handin }
    makefile = { "localFile" => local_makefile, "destFile" => "Makefile" }
    autograde = { "localFile" => local_autograde, "destFile" => "autograde.tar" }

    [handin, makefile, autograde]
  end

  ##
  # autogradeDone - called when autograding is done, either by the submissions#autograde_done
  # route getting called by Tango or by the Autograde module polling Tango. In either case,
  # submission is confirmed via dave key to have been created by Autolab
  #
  def autogradeDone(submissions, feedback)
    submissions.each do |submission|
      feedback_file = submission.create_user_directory_and_return_autograde_feedback_path
      COURSE_LOGGER.log("Looking for feedback file:" + feedback_file)

      feedback.force_encoding("UTF-8")
      if not feedback.valid_encoding?
        feedback.force_encoding("ASCII-8BIT")
        hexify = Proc.new {|c| "\\x" + c.bytes[0].to_s(16) }
        feedback = feedback.encode("UTF-8", invalid: :replace, fallback: hexify)
      end

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
      # Set job id to nil to indicate that autograding is no longer in-progress
      ActiveRecord::Base.transaction do
        submissions.each do |submission|
          submission.jobid = nil
          submission.save!
        end
      end

      lines = feedback.rstrip.lines
      raise AutogradeError.new("The Autograder returned no output", :autograde_no_output) if lines.empty?

      # The last line of the output is assumed to be the
      # autoresult string from the autograding driver
      autoresult = lines[lines.length - 1]

      if @assessment.overwrites_method?(:parseAutoresult)
        scores = @assessment.config_module.parseAutoresult(autoresult, true)
      else
        scores = parseAutoresult(autoresult, true)
      end
      raise AutogradeError.new("Empty autoresult string", :empty_autoresult) if scores.keys.length == 0

      # Grab the autograde config info
      @autograde_prop = @assessment.autograder

      # Record each of the scores extracted from the autoresult
      submissions.each do |submission|

        # If modifySubmissionScore is overridden, use that to modify the score
        # Provide it with the scores and previous submissions
        if @assessment.overwrites_method?(:modifySubmissionScores)
          
          # Get previous submissions of the same assessment by the user, excluding the current submission
          previous_submissions = Submission.where(course_user_datum_id: submission.course_user_datum_id, 
                                 assessment_id: @assessment.id)
                                 .where.not(id: submission.id)
                                 .where("created_at < ?", submission.created_at)
                                 .order(created_at: :desc)
                                 
          # If the assessment variable is set to exclude autograding in progress submissions, exclude them
          previous_submissions = if (@assessment.assessment_variable.key?("exclude_autograding_in_progress_submissions") && 
            @assessment.assessment_variable.key?("exclude_autograding_in_progress_submissions"))
                                  previous_submissions.where(jobid: nil)
                                else
                                  previous_submissions
                                end
          
          previous_submissions_lookback = if (@assessment.assessment_variable.key?("previous_submissions_lookback"))
                                            @assessment.assessment_variable["previous_submissions_lookback"]
                                          else
                                            1000 # default to 1000
                                          end 

          # Limit the number of previous submissions to the lookback value
          previous_submissions = previous_submissions.limit(previous_submissions_lookback)
          
          begin
            scores = @assessment.config_module.modifySubmissionScores(scores, previous_submissions, @assessment.problems)
          rescue StandardError => e
            # Append the error message to the feedback
            feedback_str = "An error occurred while modifying submission scores:\nError message: #{e}\n\n---\n"
            feedback = feedback_str + feedback
          end
        end

        missing_problems = []
        scores.keys.each do |key|
          problem = @assessment.problems.find_by(name: key)
          unless problem
            missing_problems << key
            next
          end

          score = submission.scores.find_or_initialize_by(problem_id: problem.id)
          score.score = scores[key]
          score.feedback = feedback 
          score.released = @autograde_prop.release_score
          score.grader_id = 0
          score.save!
        end
        submission.missing_problems = missing_problems.join(', ')
        submission.save!

        unless submission.missing_problems.empty?
          raise AutogradeError, "Problems \"#{submission.missing_problems}\" found in autograder result, but not defined by assessment. Instructor should add missing problems to assessment and regrade submissions."
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
          score.feedback = feedback_str
          if score.new_record? # don't overwrite scores
            score.score = 0
            score.released = true
            score.grader_id = -1
          end
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
    raise AutogradeError.new("Empty autoresult", :parse_autoresult) unless parsed
    raise AutogradeError.new("Missing 'scores' object in the autoresult", :parse_autoresult) unless parsed["scores"]
    parsed["scores"]
  end

  def extend_config_module(assessment, submission, cud)
    # autograde core calls might be called before migration to unique module name occurs, so need to add check
    begin
      if @assessment.use_unique_module_name
        require assessment.unique_config_file_path
      else
        require assessment.config_file_path
      end
    rescue TypeError => e
      raise AutogradeError, "could not find the assessment config file: #{e}"
    rescue LoadError => e
      raise AutogradeError, "could not load the assessment config file: #{e}"
    end


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