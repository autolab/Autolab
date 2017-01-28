##
# Handles different handin methods, including web form, local_submit and log_submit
#
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

    if @assessment.embedded_quiz

      contents = params[:submission]["embedded_quiz_form_answer"].to_s

      out_file = File.new("out.txt", "w+")
      out_file.puts(contents)

      params[:submission]["file"] = out_file

    end

    if @assessment.embedded_quiz
      if @assessment.disable_handins?
        flash[:error] = "Sorry, handins are disabled for this assessment."
        redirect_to(action: :show)
        return false
      end
    else

      # validate the handin
      redirect_to(action: :show) && return unless validateHandin

    end

    # save the submissions
    begin
      submissions = saveHandin(params[:submission])
    rescue
      submissions = nil
    end

    # make sure submission was correctly constructed and saved
    unless submissions
      # Avoid overwriting the flash[:error] set by saveHandin
      if !flash[:error].nil? && !flash[:error].empty?
        flash[:error] = "There was an error handing in your submission."
      end
      redirect_to(action: :show) && return
    end

    # autograde the submissions
    autogradeSubmissions(@course, @assessment, submissions) if @assessment.has_autograder?

    redirect_to([:history, @course, @assessment]) && return
  end

  # method called when student makes
  # unofficial submission in the database
  def local_submit
    @user = User.find_by(email: params[:user])
    @cud = @user ? @course.course_user_data.find_by(user_id: @user.id) : nil
    unless @cud
      err = "ERROR: invalid username (#{params[:user]}) for class #{@course.id}"
      render(plain: err, status: :bad_request) && return
    end

    @assessment = @course.assessments.find_by(name: params[:name])
    if !@assessment
      err = "ERROR: Invalid Assessment (#{params[:id]}) for course #{@course.id}"
      render(plain: err, status: :bad_request) && return
    elsif @assessment.remote_handin_path.nil?
      err = "ERROR: Remote handins have not been enabled by the instructor."
      render(plain: err, status: :bad_request) && return
    end

    personal_directory = @user.email + "_remote_handin_" + @assessment.name
    remote_handin_dir = File.join(@assessment.remote_handin_path, personal_directory)

    if params[:submit]
      # They've copied their handin over, lets go grab it.
      begin
        handin_file = params[:submit]

        if @assessment.max_submissions != -1
          submission_count = @cud.submissions.where(assessment: @assessment).size
          if submission_count >= @assessment.max_submissions
            render(plain: "You have no remaining submissions for this assessment",
                   status: :bad_request) && return
          end
        end

        render(plain: flash[:error], status: :bad_request) && return unless validate_for_groups

        # save the submissions
        begin
          submissions = saveHandin("local_submit_file" => File.join(remote_handin_dir, handin_file))
        rescue StandardError => e
          COURSE_LOGGER.log("Error Saving Submission:\n#{e}")
          submissions = nil
        end

        # make sure submission was correctly constructed and saved
        unless submissions
          # Avoid overwriting the flash[:error] set by saveHandin
          if !flash[:error].nil? && !flash[:error].empty?
            flash[:error] = "There was an error handing in your submission."
          end
          render(plain: flash[:error], status: :bad_request) && return
        end

        # autograde the submissions
        autogradeSubmissions(@course, @assessment, submissions) if @assessment.has_autograder?

      rescue StandardError => e
        COURSE_LOGGER.log(e.to_s)
      end

      if submissions
        COURSE_LOGGER.log("Submission received, ID##{submissions[0].id}")
      else
        err = "There was an error saving your submission. Please contact your course staff\n"
        render(plain: err, status: :bad_request) && return
      end

      if @assessment.max_submissions != -1
        remaining = @assessment.max_submissions - submissions.count
        render(plain: " - You have #{remaining} submissions left\n") && return
      end

      render(plain: "Successfully submitted\n") && return
    else

      # Create a handin directory for them.

      # The handin Directory really should not exist, as this script deletes it
      # when it's done.  However, if it's there, we'll try to remove an empty
      # folder, else fail w/ error message.
      if Dir.exist?(remote_handin_dir)
        begin
          FileUtils.rm_rf(remote_handin_dir)
        rescue SystemCallError
          render(plain: "WARNING: could not clear previous handin directory, please") && return
        end
      end

      begin
        Dir.mkdir(remote_handin_dir)
      rescue SystemCallError
        COURSE_LOGGER.log("ERROR: Could not create handin directory. Please contact
        autolab-dev@andrew.cmu.edu with this error")
      end

      system("fs sa #{remote_handin_dir} #{@user.email} rlidw")
    end

    render(plain: remote_handin_dir) && return
  end

  # method called when student makes
  # log submission in the database
  def log_submit
    @user = User.find_by(email: params[:user])
    @cud = @user ? @course.course_user_data.find_by(user_id: @user.id) : nil
    unless @cud
      err = "ERROR: invalid username (#{params[:user]}) for class #{@course.id}"
      render(plain: err, status: :bad_request) && return
    end

    @assessment = @course.assessments.find_by(name: params[:name])
    if !@assessment
      err = "ERROR: Invalid Assessment (#{params[:id]}) for course #{@course.id}"
      render(plain: err, status: :bad_request) && return
    elsif !@assessment.allow_unofficial
      err = "ERROR: This assessment does not allow Log Submissions"
      render(plain: err, status: :bad_request) && return
    end

    @result = params[:result]
    render(plain: "ERROR: No result!", status: :bad_request) && return unless @result

    # Everything looks OK, so append the autoresult to the log.txt file for this lab
    @logger = Logger.new(Rails.root.join("courses", @course.name, @assessment.name, "log.txt"))
    @logger.add(Logger::INFO) { "#{@user.email},0,#{@result}" }

    # Load up the lab.rb file
    mod_name = @assessment.name + (@course.name).gsub(/[^A-Za-z0-9]/, "")
    require(Rails.root.join("assessmentConfig", "#{@course.name}-#{@assessment.name}.rb"))
    eval("extend #{mod_name.camelcase}")

    begin
      # Call the parseAutoresult function defined in the lab.rb file.  If
      # the list of scores it returns is empty, then we the lab developer is
      # asking us not to create an unofficial submission in the
      # database. Simply return a successful status string to the client and
      # exit.
      scores = parseAutoresult(@result, false)

      render(plain: "OK", status: 200) && return if scores.keys.length == 0

      # Try to find an existing submission (always version 0).
      submission = @assessment.submissions.find_by(version: 0, course_user_datum_id: @cud.id)
      if !submission
        submission = @assessment.submissions.new(
          version: 0,
          autoresult: @result,
          user_id: @cud.id,
          submitted_by_id: 0)
        submission.save!
      else
        # update this one
        submission.autoresult = @result
        submission.created_at = Time.now
        submission.save!
      end

      # Update the scores in the db's unofficial submission using the list
      # returned by the parseAutoresult function
      scores.keys.each do |key|
        problem = @assessment.problems.find_by(name: key)
        score = submission.scores.find_or_initialize_by(problem_id: problem.id)
        score.score = scores[key]
        score.released = true
        score.grader_id = 0
        score.save!
      end
    rescue StandardError => e
      COURSE_LOGGER.log(e.to_s)
    end

    render(plain: "OK", status: 200) && return
  end

private

  ##
  # this function checks that now is a valid time to submit and that the
  # submission file is okay to submit.
  #
  def validateHandin
		if @assessment.has_custom_form
      for i in 0..@assessment.getTextfields.size-1
          if params[:submission][("formfield" + (i+1).to_s).to_sym].blank?
            flash[:error] = @assessment.getTextfields[i] + " is a required field."
            return false
          end
      end
    end
    # Make sure that handins are allowed
    if @assessment.disable_handins?
      flash[:error] = "Sorry, handins are disabled for this assessment."
      return false
    end

    # Check for if the submission is empty
    if params[:submission].nil?
      flash[:error] = "Submission was blank - please upload again."
      return false
    end
    # Check if the file is too large
    if params[:submission]["file"].size > @assessment.max_size * (2**20)
      flash[:error] = "Your submission is larger than the max allowed " \
      "size (#{@assessment.max_size} MB) - please remove any " \
        "unnecessary logfiles and binaries."
      return false
    end

    if @assessment.overwrites_method?(:checkMimeType) && !(@assessment.config_module.checkMimeType(
      params[:submission]["file"].content_type,
      params[:submission]["file"].original_filename))

      flash[:error] = "Submission failed Filetype Check. " + flash[:error]
      return false
    end

    validate_for_groups
  end

  ##
  # this function makes sure that the submitter's group can submit.
  # If the assessment does not have groups, or the user has no group,
  # this returns true.  Otherwise, it checks that everyone is confirmed
  # to be in the group and that no one is over the submission limit.
  #
  def validate_for_groups
    return true unless @assessment.has_groups?

    submitter_aud = @assessment.aud_for(@cud.id)
    return true unless submitter_aud
    group = submitter_aud.group
    return true unless group

    group.assessment_user_data.each do |aud|
      unless aud.group_confirmed
        flash[:error] = "You cannot submit until all group members confirm their group membership"
        return false
      end

      next unless @assessment.max_submissions != -1

      submission_count = aud.course_user_datum.submissions.where(assessment: @assessment).size
      next unless submission_count >= @assessment.max_submissions

      flash[:error] = "A member of your group has reached the submission limit for this assessment"
      return false
    end

    true
  end

  ##
  # this function returns a list of the submissions created by this handin.

  def saveHandin(sub)
    unless @assessment.has_groups?
      submission = @assessment.submissions.create(course_user_datum_id: @cud.id,
                                                  submitter_ip: request.remote_ip)
      submission.save_file(sub)
      return [submission]
    end

    aud = @assessment.aud_for @cud.id
    group = aud.group
    if group.nil?
      submission = @assessment.submissions.create(course_user_datum_id: @cud.id,
                                                  submitter_ip: request.remote_ip)
      submission.save_file(sub)
      return [submission]
    end

    submissions = []
    ActiveRecord::Base.transaction do
      group.course_user_data.each do |cud|
        submission = @assessment.submissions.create(course_user_datum_id: cud.id,
                                                    submitter_ip: request.remote_ip)
        submission.save_file(sub)
        submissions << submission
      end
    end
    submissions
  end

  def set_handin
    submission_count = @assessment.submissions.where(course_user_datum_id: @cud.id).count
    @left_count = [@assessment.max_submissions - submission_count, 0].max
    @aud = AssessmentUserDatum.get @assessment.id, @cud.id
    @can_submit, @why_not = @aud.can_submit? Time.now

    @submission = Submission.new
  end
end
