# Read https://github.com/autolab/autolab-src/wiki/Caching
require "association_cache"

##
# This class joins Assessments and Users, and exists mostly so that CUDs can be given special
# status (excused or whatever) on an assessment.  It's also used by Groups, and tracks the latest
# submission of the user for an assessment.
#
class AssessmentUserDatum < ApplicationRecord
  belongs_to :course_user_datum
  belongs_to :assessment
  belongs_to :latest_submission, class_name: "Submission"
  belongs_to :group

  # attr_accessible :grade_type

  # * when a new submission is made, it is possible that the number of grace days used increased
  #   so we need to invalidate the cumulative grace days used for all AUDs for assessments after
  #   this one, for this user.
  #
  # * similarly, when the grade type is updated, the number of grace days used could change.
  #   submissions associated with AUDs with Zeroed and Excused grade types aren't counted as late
  #   even if they were submitted past the due date whereas Normal grade type AUD submissions are.
  after_save :invalidate_cgdubs_for_assessments_after,
             if: :saved_change_to_latest_submission_id_or_grade_type?

  NORMAL = 0
  ZEROED = 1
  EXCUSED = 2

  GRADE_TYPE_MAP = {
    normal: NORMAL,
    zeroed: ZEROED,
    excused: EXCUSED
  }.freeze

  # Different statuses for group membership
  UNCONFIRMED = 0x0
  MEMBER_CONFIRMED = 0x1
  GROUP_CONFIRMED = 0x2
  CONFIRMED = 0x3

  ##
  # checks a user's membership status
  #
  def group_confirmed(flags = CONFIRMED)
    (flags == UNCONFIRMED && membership_status == UNCONFIRMED) ||
      ((membership_status & flags) == flags)
  end

  # Updates latest_submission atomically
  #
  # Using this method *prevents* the following interleaving, for example:
  #   1. A: <user submits submission 1>
  #   2. A: aud.latest_submission = find_latest_submission (returns submission 1)
  #   3. B: <same user submits submission 2>
  #   4. B: aud.latest_submission = find_latest_submission (returns submission 2)
  #   5. B: aud.save             (submission 2 is saved as aud.latest_submission)
  #   6. A: aud.save    (but then submission 1 is saved as aud.latest_submission)
  # by making sure (2 and 6) and (4 and 5) each occur atomically.
  def update_latest_submission
    AssessmentUserDatum.transaction do
      # acquire lock on AUD
      reload(lock: true)

      # update
      self.latest_submission = latest_submission!
      save!

      # release lock on AUD
    end
    # see: http://dev.mysql.com/doc/refman/5.0/en/innodb-locking-reads.html
  end

  # Calculate latest unignored submission (i.e. with latest max version and unignored)
  def latest_submission!
    if (max_version = Submission.where(assessment_id:,
                                       course_user_datum_id:,
                                       ignored: false).maximum(:version))
      Submission.find_by(version: max_version, assessment_id:,
                         course_user_datum_id:)
    end
  end

  def submission_status
    if latest_submission
      :submitted
    elsif past_end_at?
      :not_submitted
    else
      :not_yet_submitted
    end
  end

  def self.grade_type_to_sym(grade_type)
    case grade_type
    when NORMAL
      :normal
    when ZEROED
      :zeroed
    when EXCUSED
      :excused
    end
  end

  def final_score(as_seen_by)
    @final_score ||= {}
    @final_score[as_seen_by] ||= final_score! as_seen_by
  end

  def status(as_seen_by)
    @status ||= {}
    @status[as_seen_by] ||= status! as_seen_by
  end

  # Number of grace days available to user for this assessment
  def grace_days_usable
    course_grace_days = assessment.course.grace_days
    assessment_max_grace_days = assessment.max_grace_days

    # save doing potentially expensive stuff if not needed
    return 0 if course_grace_days == 0 || assessment_max_grace_days == 0

    grace_days_left = course_grace_days - cumulative_grace_days_used_before
    raise "fatal: negative grace days left" if grace_days_left < 0

    # if the assessment has no max_grace_days specified, then upto grace_days_left
    # number of grace days can be used on this assessment
    if assessment_max_grace_days
      [grace_days_left, assessment_max_grace_days].min
    else
      grace_days_left
    end
  end

  def grace_days_used
    (s = latest_submission) ? s.grace_days_used : 0
  end

  def penalty_late_days
    (s = latest_submission) ? s.penalty_late_days : 0
  end

  # TODO
  # Refer to https://github.com/autolab/autolab-src/wiki/Caching
  def invalidate_cgdubs_for_assessments_after
    CourseUserDatum.transaction do
      # acquire lock
      CourseUserDatum.lock(true).find(course_user_datum_id)

      # invalidate
      auds_for_assessments_after.each do |aud|
        Rails.cache.delete aud.cgdub_cache_key
      end

      Rails.cache.delete course_user_datum.ggl_cache_key

      # release lock
    end
  end

  # Due date for user
  # If there is an infinite extension, then due_at is nil.
  def due_at
    apply_extension(assessment.due_at, extension)
  end

  # Final submission deadline for user
  # If there is an infinite extension, then end_at is nil.
  def end_at(include_late_slack = true)
    s = assessment.end_at
    s += assessment.course.late_slack if include_late_slack
    apply_extension s, extension
  end

  # Check if user can submit at given date/time; provide reason, if not
  def can_submit?(at, submitter = course_user_datum)
    if submitter.instructor? || submitter.course_assistant?
      [true, nil]
    elsif course_user_datum.dropped? # TODO: why not submitter?
      [false, :user_dropped]
    elsif at < assessment.start_at
      [false, :before_start_at]
    elsif past_end_at?
      [false, :past_end_at]
    elsif at_submission_limit?
      [false, :at_submission_limit]
    else
      [true, nil]
    end
  end

  # Check if user has hit submission count limit, if one exists
  def at_submission_limit?
    if assessment.max_submissions == -1
      false
    else
      count = assessment.submissions.where(course_user_datum:).count
      count >= assessment.max_submissions
    end
  end

  def past_due_at?(as_of = Time.current)
    due_at && due_at < as_of
  end

  def past_end_at?(as_of = Time.current)
    end_at && end_at < as_of
  end

  def extension
    Extension.find_by(course_user_datum:, assessment_id:)
  end

  def self.get(assessment_id, cud_id)
    find_by assessment_id:, course_user_datum_id: cud_id
  end

  # Quickly create an AUD (without any callbacks, validations, AR object creation, etc.)
  def self.create_modulo_callbacks(params)
    columns = params.keys
    values = params.values_at(*columns)

    columns_sql = columns.join(", ")
    values_sql = values.join(", ")

    insert_sql = "INSERT INTO #{table_name} (#{columns_sql}) VALUES (#{values_sql})"
    connection.execute insert_sql
  end

  def global_cumulative_grace_days_used
    cumulative_grace_days_used
  end

  # atomic way of updating version number
  # (necessary in the case multiple submissions made concurrently)
  def update_version_number
    with_lock do
      if version_number.nil?
        self.version_number = 1
      else
        self.version_number += 1
      end
      save!
    end
    self.version_number
  end

  def leave_group
    self.group_id = nil
    self.membership_status = UNCONFIRMED
    save!
  end

  def delete_version_number
    with_lock do
      max_version = Submission.where(assessment_id:,
                                     course_user_datum_id:,
                                     ignored: false).maximum(:version)
      self.version_number = if max_version.nil?
                              0
                            else
                              max_version
                            end
      save!
    end
    self.version_number
  end

protected

  def cumulative_grace_days_used
    grace_days_used + cumulative_grace_days_used_before
  end

  def cgdub_cache_key
    # gets it into the YYYYMMDDHHMMSS form
    dua = assessment.course.cgdub_dependencies_updated_at.utc.to_s(:number)

    "cgdub/dua-#{dua}/u-#{course_user_datum_id}/a-#{assessment_id}"
  end

private

  def saved_change_to_latest_submission_id_or_grade_type?
    saved_change_to_latest_submission_id? or saved_change_to_grade_type?
  end

  # Applies given extension to given date limit (due date or end_at).
  # Returns nil, if extension is infinite and thus the date limit is void.
  def apply_extension(original_date, ext)
    if ext
      ext.infinite? ? nil : (original_date + ext.days.days)
    else
      original_date
    end
  end

  def cumulative_grace_days_used_before
    return @cgdub if @cgdub

    cache_key = cgdub_cache_key

    unless (cgdub = Rails.cache.read cache_key)
      CourseUserDatum.transaction do
        # acquire lock on user
        CourseUserDatum.lock(true).find(course_user_datum_id)

        # compute
        cgdub = cumulative_grace_days_used_before!

        # cache
        Rails.cache.write(cache_key, cgdub, expires_in: 7.days, race_condition_ttl: 1.minute)

        # release lock
      end
    end

    @cgdub = cgdub
  end

  # TODO: CA's shouldn't see non-normal
  # TODO: make above policy
  def final_score!(as_seen_by)
    case grade_type
    when NORMAL
      if latest_submission
        latest_submission.final_score as_seen_by
      else
        0.0
      end
    when ZEROED
      0.0
    when EXCUSED
      nil
    end
  end

  # the consolidated status of a student on an assessment
  #
  # as of 09/21/2013, the return value is:
  #
  # if grade type is
  # - normal:
  #     if submission status is
  #       - submitted => latest submission's final score (float)
  #       - not submitted => :not_submitted
  #       - not yet submitted => :not_yet_submitted
  # - excused => :excused
  # - zeroed => :zeroed
  #
  # this is currently used by gradebook#csv export.
  def status!(as_seen_by)
    if grade_type == NORMAL
      if submission_status == :submitted
        latest_submission.final_score as_seen_by
      else # :not_yet_submitted, :not_submitted
        submission_status
      end
    else # ZEROED, EXCUSED
      AssessmentUserDatum.grade_type_to_sym grade_type
    end
  end

  def cumulative_grace_days_used_before!
    # if there's no previous, this is the first assessment of the course
    if (aud_before = aud_for_assessment_before)
      aud_before.cumulative_grace_days_used
    else
      0
    end
  end

  def aud_for_assessment_before
    return unless (assessment_before = assessment.assessment_before)

    assessment_before.aud_for course_user_datum_id
  end

  def auds_for_assessments_after
    auds = course_user_datum.assessment_user_data.joins(:assessment).order(Assessment::ORDERING).all
    self_index = auds.index self
    auds.drop(self_index + 1)
  end

  include AUDAssociationCache
end
