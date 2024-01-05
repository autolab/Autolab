require "archive"

class Api::V1::AssessmentsController < Api::V1::BaseApiController

  include AssessmentHandinCore
  include AssessmentAutogradeCore

  before_action -> {require_privilege :user_courses}, only: [:index, :problems, :writeup, :handout]
  before_action -> {require_privilege :user_submit}, only: [:submit]
  before_action -> {require_privilege :instructor_all}, only: [:set_group_settings]

  before_action :set_assessment, except: [:index]

  def index
    asmts = @course.assessments.ordered
    allowed = [:name, :display_name, :start_at, :due_at, :end_at, :category_name]
    if @cud.student?
      asmts = asmts.released
    else
      allowed += [:grading_deadline]
    end

    respond_with asmts, only: allowed
  end

  def show
    allowed = [:name, :display_name, :description, :start_at, :due_at, :end_at, :updated_at, :max_grace_days, :max_submissions,
      :disable_handins, :category_name, :group_size, :writeup_format, :handout_format, :has_scoreboard, :has_autograder, :max_unpenalized_submissions]
    if not @cud.student?
      allowed += [:grading_deadline]
    end

    result = @assessment.attributes.symbolize_keys
    result.merge!(:has_scoreboard => @assessment.has_scoreboard?)
    result.merge!(:has_autograder => @assessment.has_autograder?)
    result.merge!(:max_unpenalized_submissions => @assessment.effective_version_threshold)
    if @assessment.writeup_is_file?
      result.merge!(:writeup_format => "file")
    elsif @assessment.writeup_is_url?
      result.merge!(:writeup_format => "url")
    else
      result.merge!(:writeup_format => "none")
    end
    if @assessment.overwrites_method?(:handout) or @assessment.handout_is_file?
      result.merge!(:handout_format => "file")
    elsif @assessment.handout_is_url?
      result.merge!(:handout_format => "url")
    else
      result.merge!(:handout_format => "none")
    end

    respond_with result, only: allowed
  end

  # endpoint for obtaining the writeup
  def writeup
    if @assessment.writeup_is_url?
      respond_with_hash({:url => @assessment.writeup}) and return
    end

    if @assessment.writeup_is_file?
      # Note: writeup_is_file? validates that the writeup lies within the assessment folder
      filename = @assessment.writeup_path
      send_file(filename,
                disposition: "inline",
                file: File.basename(filename))
      return
    end

    respond_with_hash({:writeup => "none"})
  end

  # endpoint for obtaining the handout
  def handout
    extend_config_module(@assessment, nil, @cud)

    if @assessment.overwrites_method?(:handout)
      hash = @assessment.config_module.handout
      # Ensure that handout lies within the assessment folder
      unless Archive.in_dir?(Pathname(hash["fullpath"]), @assessment.folder_path)
        respond_with_hash({:handout => "none"}) and return
      end

      send_file(hash["fullpath"],
                disposition: "inline",
                filename: hash["filename"])
      return
    end

    if @assessment.handout_is_url?
      respond_with_hash({:url => @assessment.handout}) and return
    end

    if @assessment.handout_is_file?
      # Note: handout_is_file? validates that the handout lies within the assessment folder
      filename = @assessment.handout_path
      send_file(filename,
                disposition: "inline",
                file: File.basename(filename))
      return
    end

    respond_with_hash({:handout => "none"})
  end

  # endpoint for submitting to assessments
  # Does not support embedded quizzes.
  # Potential Errors:
  #   Submission Rejected:
  #   - Assessment is an embedded quiz
  #   - Handins disabled
  #   - Submitting late without submit-late flag
  #   - Past assessment end time
  #   - Before assessment start time
  #   - Exceeded max submission count
  #   - Exceeded max handin file size
  #   - Submission was blank
  #   - Submission failed file type check
  #   - Cannot submit until all group members confirm their group membership
  #   - A member of your group has reached the submission limit for this assessment
  #   Autograding Failed:
  #   - No autograding properties
  #   - Error submitting job
  #   - Error uploading submission file
  #   - Submission rejected by autograder
  #   - One or more files in the Autograder module don't exist.
  #   - Encountered unexpected exception
  def submit
    if @assessment.embedded_quiz
      raise ApiError.new("Assessment is an embedded quiz", :bad_request)
    end

    if not params.has_key?(:submission)
      raise ApiError.new("Required parameter 'submission' not found", :bad_request)
    end

    if not params[:submission].has_key?("file")
      raise ApiError.new("Required parameter 'submission['file']' not found", :bad_request)
    end

    # validate Handin
    validity = validateHandin(params[:submission]["file"].size,
                              params[:submission]["file"].content_type,
                              params[:submission]["file"].original_filename)
    case validity
    when :valid
    when :handin_disabled
      raise ApiError.new("Handins for this assessment is disabled", :forbidden)
    when :submission_empty
      raise ApiError.new("Submission was blank", :forbidden)
    when :file_too_large
      msg = "Submission is larger than the max allowed " \
            "size (#{@assessment.max_size} MB) - please remove any " \
            "unnecessary logfiles and binaries."
      raise ApiError.new(msg, :forbidden)
    when :fail_type_check
      raise ApiError.new("Submission failed Filetype Check", :forbidden)
    else
      raise ApiError.new("Unexpected error during handin validation", :forbidden)
    end

    group_validity = validateHandinForGroups()
    case group_validity
    when :valid
    when :awaiting_member_confirmation
      raise ApiError.new("Submission not allowed until all group members confirm their group membership", :forbidden)
    when :group_submission_limit_exceeded
      raise ApiError.new("A member of your group has reached the submission limit for this assessment", :forbidden)
    else
      raise ApiError.new("Unexpected error during handin validation for groups", :forbidden)
    end

    # attempt to save the submission
    begin
      submissions = saveHandin(params[:submission], current_app.id)
    rescue StandardError => e
      # TODO: log error
      raise ApiError.new("Unexpected error during submission handin.\nDetails: #{e.message}", :internal_server_error)
    end

    # autograde the submission
    if @assessment.has_autograder?
      begin
        sendJob(@course, @assessment, submissions, @cud)
      rescue AssessmentAutogradeCore::AutogradeError => e
        raise ApiError.new("Submission accepted, but autograding failed: " + e.message, :internal_server_error)
      end
    end

    respond_with_hash({version: submissions[0].version, filename: submissions[0].filename})
  end

  def set_group_settings
    require_params([:group_size, :allow_student_assign_group])
    @assessment.group_size = params[:group_size].to_i
    @assessment.allow_student_assign_group = (params[:allow_student_assign_group].to_s == "true")
    @assessment.save!
    respond_with_hash({ group_size: @assessment.group_size, 
      allow_student_assign_group: @assessment.allow_student_assign_group })
  end

end