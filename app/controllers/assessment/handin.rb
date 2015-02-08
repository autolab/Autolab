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
      submissions = saveHandin
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
  
  private

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
        submission_count = aud.course_user_datum.submissions.size
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
  
  def saveHandin
    if !@assessment.has_groups? then
      submission = @assessment.submissions.create(course_user_datum_id: @cud.id,
                                                  submitter_ip: request.remote_ip)
      submission.saveFile(params[:submission])
      return [submission]
    end
      
    aud = @assessment.aud_for @cud.id
    group = aud.group
    if group.nil? then
      submission = @assessment.submissions.create(course_user_datum_id: @cud.id,
                                                  submitter_ip: request.remote_ip)
      submission.saveFile(params[:submission])
      return [submission]
    end
    
    submissions = []
    ActiveRecord::Base.transaction do
      group.course_user_data.each do |cud|
        submission = @assessment.submissions.create(course_user_datum_id: cud.id,
                                                    submitter_ip: request.remote_ip)
        submission.saveFile(params[:submission])
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
