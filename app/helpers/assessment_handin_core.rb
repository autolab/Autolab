module AssessmentHandinCore

  ##
  # validateHandin - makes sure the handin is valid according to the
  #   assessment config.
  # Note: this function does not automatically check for group handin
  # validity. To check for that as well, run validateHandinForGroups.
  def validateHandin(size, content_type, filename)
    # Make sure that handins are allowed
    if @assessment.disable_handins?
      return :handin_disabled
    end
    # Check for if the submission is empty
    if params[:submission].nil?
      return :submission_empty
    end
    # Check if the file is too large
    if size > @assessment.max_size * (2**20)
      return :file_too_large
    end

    # Check if mimetype is correct (if overwritten by assessment config)
    begin
      if @assessment.overwrites_method?(:checkMimeType) and 
        not @assessment.config_module.checkMimeType(content_type, filename)
        return :fail_type_check
      end
    rescue RuntimeError => e
      flash[:error] = e.message
      return :fail_type_check
    end

    return :valid
  end

  ##
  # validateHandinForGroups - makes sure that the submitter's group can submit.
  # If the assessment does not have groups, or the user has no group,
  # this returns :valid. Otherwise, it checks that everyone is confirmed
  # to be in the group and that no one is over the submission limit.
  def validateHandinForGroups
    return :valid unless @assessment.has_groups?

    submitter_aud = @assessment.aud_for(@cud.id)
    return :valid unless submitter_aud

    group = submitter_aud.group
    return :valid unless group

    group.assessment_user_data.each do |aud|
      unless aud.group_confirmed
        return :awaiting_member_confirmation
      end

      next unless @assessment.max_submissions != -1

      submission_count = aud.course_user_datum.submissions.where(assessment: @assessment).size
      next unless submission_count >= @assessment.max_submissions

      return :group_submission_limit_exceeded
    end

    return :valid
  end

  ##
  # saveHandin - saves the submission to database. If this submission is by a member of
  # a group, it creates a submissions record for each person.
  # 
  # params:
  #  - sub: submission file (to be saved by this method).
  #  - app_id: [Optional] id of the application that made this submission.
  #            default is nil, meaning no application was used (handed in directly from 
  #            webpage, either by student or by an instructor).
  # Returns a list of the submissions created by this handin (aka a "logical submission").
  def saveHandin(sub, app_id = nil)
    unless @assessment.has_groups?
      submission = @assessment.submissions.create!(course_user_datum_id: @cud.id,
                                                  submitter_ip: request.remote_ip,
                                                  submitted_by_app_id: app_id)
      submission.save_file(sub)
      return [submission]
    end

    aud = @assessment.aud_for @cud.id
    group = aud.group
    if group.nil?
      submission = @assessment.submissions.create!(course_user_datum_id: @cud.id,
                                                  submitter_ip: request.remote_ip,
                                                  submitted_by_app_id: app_id)
      submission.save_file(sub)
      return [submission]
    end

    submissions = []

    # group_key = group_name_submitter_email_handin_filename_timestamp
    group_key = "#{group.name}_#{@cud.user.email}_#{@assessment.handin_filename}_"
    group_key += Time.current.utc.to_s(:number)

    ActiveRecord::Base.transaction do
      group.course_user_data.each do |cud|
        submission = @assessment.submissions.create!(course_user_datum_id: cud.id,
                                                    submitter_ip: request.remote_ip,
                                                    submitted_by_app_id: app_id,
                                                    group_key: group_key)
        submission.save_file(sub)
        submissions << submission
      end
    end
    submissions
  end

end