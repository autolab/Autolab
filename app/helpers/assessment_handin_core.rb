# frozen_string_literal: true

module AssessmentHandinCore
  ##
  # validateHandin - makes sure the handin is valid according to the
  #   assessment config.
  # Note: this function does not automatically check for group handin
  # validity. To check for that as well, run validateHandinForGroups.
  def validateHandin(size, content_type, filename)
    # Make sure that handins are allowed
    return :handin_disabled if @assessment.disable_handins?
    # Check for if the submission is empty
    return :submission_empty if params[:submission].nil?
    # Check if the file is too large
    return :file_too_large if size > @assessment.max_size * (2**20)
    # Check if mimetype is correct (if overwritten by assessment config)
    if @assessment.overwrites_method?(:checkMimeType) &&
       !@assessment.config_module.checkMimeType(content_type, filename)
      return :fail_type_check
    end

    :valid
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
      return :awaiting_member_confirmation unless aud.group_confirmed

      next unless @assessment.max_submissions != -1

      submission_count = aud.course_user_datum.submissions.where(assessment: @assessment).size
      next unless submission_count >= @assessment.max_submissions

      return :group_submission_limit_exceeded
    end

    :valid
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
      submission = @assessment.submissions.create(course_user_datum_id: @cud.id,
                                                  submitter_ip: request.remote_ip,
                                                  submitted_by_app_id: app_id)
      submission.save_file(sub)
      return [submission]
    end

    aud = @assessment.aud_for @cud.id
    group = aud.group
    if group.nil?
      submission = @assessment.submissions.create(course_user_datum_id: @cud.id,
                                                  submitter_ip: request.remote_ip,
                                                  submitted_by_app_id: app_id)
      submission.save_file(sub)
      return [submission]
    end

    submissions = []
    ActiveRecord::Base.transaction do
      group.course_user_data.each do |cud|
        submission = @assessment.submissions.create(course_user_datum_id: cud.id,
                                                    submitter_ip: request.remote_ip,
                                                    submitted_by_app_id: app_id)
        submission.save_file(sub)
        submissions << submission
      end
    end
    submissions
  end
end
