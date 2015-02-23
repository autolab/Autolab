module AssessmentHandin 
  
  # handin - The generic default handin function. 
  # This function calls out to smaller helper functions which provide for
  # specific functionality. 
  # 
  # validateHandin() : Returns true or false if the handin is valid.
  # saveHandin() : Does the actual process of saving the handin to the
  #     database and writing the handin file to Disk. 
  # autogradeSubmissions(course, assessment, submissions): Does any post-handing-in actions.
  #     arguments are the course object, assessment object, and a list of submissions objects
  # 
  # Both validateHandin() and autogradeSubmissions() cannot modify the state of the
  # world in any way. And they both should call super() to enable any other
  # functionality.  The only reason to not call super() is if you want to
  # prevent other functionlity.  You should be very careful about this.
  #
  # Any errors should be added to flash[:error] and return false or nil.
  def handin
    # validate the handin
    unless validateHandin then
      redirect_to :action => :show and return
    end

    # save the submissions
    begin
      submissions = saveHandin(params[:submission])
    rescue Exception => e
      submissions = nil
    end

    # make sure submission was correctly constructed and saved
    unless submissions then
      # Avoid overwriting the flash[:error] set by saveHandin
      if (!flash[:error].nil? && !flash[:error].empty?) then
        flash[:error] = "There was an error handing in your submission."
      end
      redirect_to action: :show and return
    end

    # autograde the submissions
    if @assessment.has_autograde then
      autogradeSubmissions(@course, @assessment, submissions)
    end

    redirect_to [:history, @course, @assessment] and return
  end
  
  # method called when student makes
  # unofficial submission in the database
  def local_submit
    @course = Course.find(params[:course_id])
    if !@course then
      render plain: "ERROR: invalid course", status: :bad_request and return
    end
    
    @user = User.find_by(email: params[:user])
    @cud = @user and @course.course_user_data.find_by(user_id: @user.id)
    if !@cud then
      err = "ERROR: invalid username (#{params[:user]}) for class #{@course.id}"
      render plain: err, status: :bad_request and return
    end

    @assessment = @course.assessments.find(params[:id])
    if !@assessment then
      err = "ERROR: Invalid Assessment (#{params[:id]}) for course #{@course.id}"
      render plain: err, status: :bad_request and return
    elsif @assessment.remote_handin_path.nil? then
      err = "ERROR: Remote handins have not been enabled by the instructor."
      render plain: err, status: :bad_request and return
    end

    personal_directory = @user.email + "_remote_handin_" +  @assessment.name
    remoteHandinDir = File.join(@assessment.remote_handin_path, personal_directory)

    submission_count = 0
      
    if (params[:submit]) then
      #They've copied their handin over, lets go grab it. 
      begin
        handinFile = params[:submit]
        
        @cud = @course.course_user_data.find_by(email: @user.email)
        if @assessment.max_submissions != -1 then
          submission_count = @cud.submissions.where(assessment: @assessment).size
          if submission_count >= @assessment.max_submissions then
            render plain: "You have no remaining submissions for this assessment", status: :bad_request and return
          end
        end
        
        unless validateForGroups() then
          render plain: flash[:error], status: :bad_request and return
        end
        
        # save the submissions
        begin
          submissions = saveHandin({'local_submit_file'=>File.join(remoteHandinDir, handinFile)})
        rescue Exception => e
          submissions = nil
        end
        
        # make sure submission was correctly constructed and saved
        unless submissions then
          # Avoid overwriting the flash[:error] set by saveHandin
          if (!flash[:error].nil? && !flash[:error].empty?) then
            flash[:error] = "There was an error handing in your submission."
          end
          render plain: flash[:error], status: :bad_request and return
        end

        # autograde the submissions
        if @assessment.has_autograde then
          autogradeSubmissions(@course, @assessment, submissions)
        end

      rescue Exception  => e
        print e
        COURSE_LOGGER.log(e.to_s)
      end

      if (submissions) then
        puts "Submission received, ID##{submissions[0].id}"
      else
        err = "There was an error saving your submission. Please contact your course staff"
        render plain: err, status: :bad_request and return
      end

      if @assessment.max_submissions != -1 then
        render plain: " - You have #{assessment.max_submissions - submissons_count} submissions left" and return
      end
    
      render plain: "Successfully submitted" and return
    else
      
      # Create a handin directory for them. 

      # The handin Directory really should not exist, as this script deletes it
      # when it's done.  However, if it's there, we'll try to remove an empty
      # folder, else fail w/ error message. 
      if (Dir.exist?(remoteHandinDir)) then
        begin
          FileUtils.rm_rf(remoteHandinDir)
        rescue SystemCallError 
          render plain: "WARNING: could not clear previous handin directory, please" and return
        end
      end

      begin
        Dir.mkdir(remoteHandinDir)
      rescue SystemCallError
        puts "ERROR: Could not create handin directory. Please contact
        autolab-dev@andrew.cmu.edu with this error" 
      end

      system("fs sa #{remoteHandinDir} #{@user.email} rlidw")
    end

    render plain: remoteHandinDir and return
  end

  # method called when student makes
  # log submission in the database
  def log_submit
    @course = Course.find(params[:course_id])
    if !@course then
      render plain: "ERROR: invalid course", status: :bad_request and return
    end
    
    @user = User.find_by(email: params[:user])
    @cud = @user and @course.course_user_data.find_by(user_id: @user.id)
    if !@cud then
      err = "ERROR: invalid username (#{params[:user]}) for class #{@course.id}"
      render plain: err, status: :bad_request and return
    end

    @assessment = @course.assessments.find(params[:id])
    if !@assessment then
      err = "ERROR: Invalid Assessment (#{params[:id]}) for course #{@course.id}"
      render plain: err, status: :bad_request and return
    elsif !@assessment.allow_unofficial then
      err = "ERROR: This assessment does not allow Log Submissions"
      render plain: err, status: :bad_request and return
    end

    @result = params[:result]
    if !@result then
      render plain: "ERROR: No result!", status: :bad_request and return
    end

    # Everything looks OK, so append the autoresult to the log.txt file for this lab
    @logger = Logger.new(Rails.root.join("courses", @course.name, @assessment.name, "log.txt"))
    @logger.add(Logger::INFO) { "#{@user.email},0,#{@result}" }

    # Load up the lab.rb file
    modName = @assessment.name + (@course.name).gsub(/[^A-Za-z0-9]/,"")
    require(Rails.root.join("assessmentConfig", "#{@course.name}-#{@assessment.name}.rb"))
    eval("extend #{modName.camelcase}")

    begin
      # Call the parseAutoresult function defined in the lab.rb file.  If
      # the list of scores it returns is empty, then we the lab developer is
      # asking us not to create an unofficial submission in the
      # database. Simply return a successful status string to the client and
      # exit.
      scores = parseAutoresult(@result,false)

      if scores.keys.length == 0 then 
        render plain: "OK", status: 200 and return
      end

      # Try to find an existing submission (always version 0). 
      submission = @assessment.submissions.find_by(version: 0, course_user_datum_id: @cud.id)
      if !submission then
        submission = @assessment.submissions.new(
              version: 0,
              autoresult: @result,
              user_id: @cud.id,
              submitted_by_id: 0)
        submission.save!()
      else
        #update this one
        submission.autoresult = @result
        submission.created_at = Time.now()
        submission.save!()
      end

      # Update the scores in the db's unofficial submission using the list
      # returned by the parseAutoresult function
      for key in scores.keys do
        problem = @assessment.problems.find_by(name: key)
        score = submission.scores.find_or_initialize_by(problem_id: problem.id)
        score.score = scores[key]
        score.released = true
        score.grader_id = 0
        score.save!()
      end
    rescue Exception  => e
      print e
    end

    render plain: "OK", status: 200 and return
  end

  private

  ##
  # this function checks that now is a valid time to submit and that the
  # submission file is okay to submit.
  #
  def validateHandin
    # Make sure that handins are allowed 
    if @assessment.disable_handins? then
      flash[:error] = "Sorry, handins are disabled for this assessment."
      return false
    end

    # Check for if the submission is empty
    if (params[:submission].nil?) then
      flash[:error] = "Submission was blank - please upload again."
      return false
    end
    # Check if the file is too large
    if params[:submission]['file'].size > @assessment.max_size*(2**20) then
      flash[:error] = "Your submission is larger than the max allowed " +
      "size (#{@assessment.max_size.to_s} MB) - please remove any " +
        "unnecessary logfiles and binaries."
      return false
    end

    if @assessment.overwrites_method?(:checkMimeType) \
      and !(@assessment.config_module.checkMimeType(
        params[:submission]['file'].content_type,
        params[:submission]['file'].original_filename)) then

      flash[:error] = "Submission failed Filetype Check. " + flash[:error]
      return false
    end
      
    return validateForGroups()
  end

  ##
  # this function makes sure that the submitter's group can submit.
  # If the assessment does not have groups, or the user has no group,
  # this returns true.  Otherwise, it checks that everyone is confirmed
  # to be in the group and that no one is over the submission limit.
  #
  def validateForGroups
    unless @assessment.has_groups? then
      return true
    end
      
    aud = @assessment.aud_for(@cud.id) or return true
    group = aud.group or return true
    
    group.assessment_user_data.each do |aud|
      unless aud.group_confirmed then
        flash[:error] = "You cannot submit until all group members confirm their group membership"
        return false
      end
      
      if @assessment.max_submissions != -1 then
        submission_count = aud.course_user_datum.submissions.where(assessment: @assessment).size
        if submission_count >= @assessment.max_submissions then
          flash[:error] = "A member of your group has reached the submission limit for this assessment"
          return false
        end
      end
    end
    
    return true
  end
  
  ##
  # this function returns a list of the submissions created by this handin.
  
  def saveHandin(sub)
    if !@assessment.has_groups? then
      submission = @assessment.submissions.create(course_user_datum_id: @cud.id,
                                                  submitter_ip: request.remote_ip)
      submission.saveFile(sub)
      return [submission]
    end
      
    aud = @assessment.aud_for @cud.id
    group = aud.group
    if group.nil? then
      submission = @assessment.submissions.create(course_user_datum_id: @cud.id,
                                                  submitter_ip: request.remote_ip)
      submission.saveFile(sub)
      return [submission]
    end
    
    submissions = []
    ActiveRecord::Base.transaction do
      group.course_user_data.each do |cud|
        submission = @assessment.submissions.create(course_user_datum_id: cud.id,
                                                    submitter_ip: request.remote_ip)
        submission.saveFile(sub)
        submissions << submission
      end
    end
    return submissions
  end

  def get_handin
    if @assessment.nil? then
      @assessment = @course.assessments.find(params[:assessment_id])
    end

    submission_count = @assessment.submissions.where(course_user_datum_id: @cud.id).count
    @left_count = [ @assessment.max_submissions - submission_count, 0 ].max
    @aud = AssessmentUserDatum.get @assessment.id, @cud.id
    @can_submit, @why_not = @aud.can_submit? Time.now
    @is_quiz = @assessment.quiz
    @quiz_path = takeQuiz_course_assessment_path(@course, @assessment)

    @submission = Submission.new
  end

end 
