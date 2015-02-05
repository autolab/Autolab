module AssessmentHandin 
  
  # handin - The generic default handin function. 
  # This function calls out to smaller helper functions which provide for
  # specific functionality. 
  # 
  # validateHandin() : Returns true or false if the handin is valid.
  # saveHandin() : Does the actual process of saving the handin to the
  #     database and writing the handin file to Disk. 
  # autogradeAfterHandin(@submission): Does any post-handing-in actions. Argument is
  #     the database Submission object. 
  # 
  # Both validateHandin() and autogradeAfterHandin() cannot modify the state of the
  # world in any way. And they both should call super() to enable any other
  # functionality.  The only reason to not call super() is if you want to
  # prevent other functionlity.  You should be very careful about this.
  #
  # Any errors should be added to flash[:error] and return false or nil.
  def handin
    # processing handin
    # call validateHandin, saveHandin, autogradeAfterHandin and partnersAfterHandin callbacks
    unless validateHandin
      redirect_to :action => :show and return
    end

    @submission = saveHandin

    # make sure submission was correctly constructed and saved
    unless @submission and !@submission.new_record?
      # Avoid overwriting the flash[:error] set by saveHandin
      if (!flash[:error].nil? && !flash[:error].empty?) then
        flash[:error] = "There was an error handing in your submission."
      end
      redirect_to :action => :show and return
    end


    if @assessment.has_autograde then
      autogradeAfterHandin @submission
    elsif @assessment.has_partners then
      partnersAfterHandin @submission
    end

    redirect_to [:history, @course, @assessment] and return
  end
  
  private

  def validateHandin()
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
    return true
  end

  def saveHandin()
    @submission = Submission.create(:assessment_id => @assessment.id,
                                    :course_user_datum_id => @cud.id,
                                    :submitter_ip => request.remote_ip)
    @submission.saveFile(params[:submission])
    return @submission
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
