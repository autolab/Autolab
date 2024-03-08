require "fileutils"
require "utilities"
require "association_cache"
require "json"
##
# Submissions jointly belong to Assessments and CourseUserData
#
class Submission < ApplicationRecord
  attr_accessor :header_position

  trim_field :filename, :notes, :mime_type

  belongs_to :course_user_datum
  belongs_to :assessment
  has_many :scores, dependent: :destroy
  belongs_to :submitted_by, class_name: "CourseUserDatum"
  belongs_to :tweak, class_name: "Tweak"
  accepts_nested_attributes_for :tweak, allow_destroy: true
  has_one :assessment_user_datum, foreign_key: "latest_submission_id"

  validate :allowed?, on: :create
  validates_associated :assessment
  validate :user_and_assessment_in_same_course
  validates :notes, length: { maximum: 255 }

  has_many :annotations, dependent: :destroy

  before_save :detect_mime_type
  before_destroy :archive_handin
  before_validation :set_version, on: :create

  # keep track of latest submission
  after_save :update_latest_submission, if: :version_changed?
  after_save :update_latest_submission, if: :ignored_changed?
  after_commit do |sub|
    COURSE_LOGGER.log("Submission #{sub.id} SAVED for " \
      "#{sub.course_user_datum.user.email} on" \
      " #{sub.assessment.name}, file #{sub.filename} (#{sub.mime_type}),"\
      "version: #{sub.version}")
  end

  after_create :update_latest_submission
  after_destroy :delete_version_number
  after_destroy :update_latest_submission

  # allow stuff to get updated by mass assign
  # attr_accessible :notes, :tweak_attributes

  # latest (unignored) submissions
  scope :latest, -> { joins(:assessment_user_datum).joins(:course_user_datum) }
  scope :latest_for_statistics, lambda {
                                  joins(:assessment_user_datum).where.not(assessment_user_data:
                                    { grade_type:
                                      AssessmentUserDatum::EXCUSED }).joins(:course_user_datum)
                                }

  # constants for special submission types
  NORMAL = 0
  NG = 1
  EXC = 2

  # since we enforce that a submission's version is immutable, it seems
  # like we should take advantage of the fact and special case an after_create
  # filter to update the latest submission to the one being created (instead of
  # computing it). but this is *not* the case due it opening the possibility of
  # race conditions.
  #
  # in fact, *not* assuming self is the latest submission here is the very
  # reason why this caching works and isn't susceptible to race conditions
  # (such as: someone submits twice quickly in succession and the first
  # update_latest_submission happens after the second).
  #
  # because we actually compute the latest submission in update_latest_submission
  # instead of just using self, we're guaranteed that the latest submission will
  # indeed be cached as such, irrespective of the interleaving. the invariant being
  # that, whatever the interleaving, the last thing that happens will be an
  # update_latest_submission which will atomically compute the latest submission
  # and cache it in the AUD (assessment_user_data).
  delegate :update_latest_submission, to: :aud
  delegate :delete_version_number, to: :aud

  def save_file(upload)
    self.filename = handin_file_filename

    if upload["file"]
      # Sanity!
      upload["file"].rewind
      File.open(create_user_directory_and_return_handin_file_path, "wb") { |f|
        f.write(upload["file"].read)
      }
    elsif upload["local_submit_file"]
      # local_submit_file is a path string to the temporary handin
      # directory we create for local submissions
      File.open(create_user_directory_and_return_handin_file_path, "wb") do |f|
        f.write(File.read(upload["local_submit_file"], mode: File::RDONLY | File::NOFOLLOW))
      end
    elsif upload["tar"]
      src = upload["tar"]
      # Only used for Github submissions, so this is fairly safe
      FileUtils.mv(src, create_user_directory_and_return_handin_file_path)
    end

    if upload["file"]
      begin
        self.mime_type = upload["file"].content_type
      rescue StandardError
        self.mime_type = nil
      end
      self.mime_type = "text/plain" unless mime_type
    elsif upload["local_submit_file"]
      self.mime_type = "text/plain"
    elsif upload["tar"]
      self.mime_type = "application/x-tgz"
    end
    save!
  end

  def archive_handin
    return if assessment.disable_handins
    return if filename.nil?
    return unless File.exist?(handin_file_path)

    FileUtils.mkdir_p handin_archive_path

    # Archive handin file
    FileUtils.mv(handin_file_path, submission_archive_path)

    # Archive feedback file
    if assessment.has_autograder? && File.exist?(autograde_feedback_path)
      FileUtils.mv(autograde_feedback_path, feedback_archive_path)
    end

    # Archive annotated file
    return unless File.exist?(handin_annotated_file_path)

    FileUtils.mv(handin_annotated_file_path, annotated_archive_path)
  end

  ### archive helpers
  def handin_archive_path
    File.join(assessment.handin_directory_path, "archive", course_user_datum.email)
  end

  def submission_archive_path
    submission_archive_filename = "#{id}_#{filename}"
    File.join(handin_archive_path, submission_archive_filename)
  end

  def feedback_archive_path
    feedback_archive_filename = "#{id}_#{autograde_feedback_filename}"
    File.join(handin_archive_path, feedback_archive_filename)
  end

  def annotated_archive_path
    annotated_archive_filename = "#{id}_annotated_#{filename}"
    File.join(handin_archive_path, annotated_archive_filename)
  end

  ### handin helpers
  def create_user_handin_directory
    FileUtils.mkdir_p File.join(assessment.handin_directory_path, course_user_datum.email)
  end

  def handin_file_filename
    "#{version}_#{assessment.handin_filename}"
  end

  def handin_file_long_filename
    "#{course_user_datum.email}_#{version}_#{assessment.handin_filename}"
  end

  def new_handin_file_path
    File.join(assessment.handin_directory_path, course_user_datum.email, filename)
  end

  def handin_file_path
    return nil unless filename

    old_handin_file_path = File.join(assessment.handin_directory_path, filename)
    unless File.exist?(old_handin_file_path)
      return new_handin_file_path
    end

    old_handin_file_path
  end

  def create_user_directory_and_return_handin_file_path
    return nil unless filename

    create_user_handin_directory
    new_handin_file_path
  end

  def handin_annotated_file_path
    return nil unless filename

    new_handin_annotated_file_path = File.join(assessment.handin_directory_path,
                                               course_user_datum.email, "annotated_#{filename}")
    old_handin_annotated_file_path = File.join(assessment.handin_directory_path,
                                               "annotated_#{filename}")
    unless File.exist?(old_handin_annotated_file_path)
      return new_handin_annotated_file_path
    end

    old_handin_annotated_file_path
  end

  def autograde_feedback_filename
    "#{version}_autograde.txt"
  end

  def old_autograde_feedback_filename
    "#{course_user_datum.email}_#{version}_#{assessment.name}_autograde.txt"
  end

  def new_autograde_feedback_path
    File.join(assessment.handin_directory_path, course_user_datum.email,
              autograde_feedback_filename)
  end

  def autograde_feedback_path
    old_autograde_feedback_path = File.join(assessment.handin_directory_path,
                                            old_autograde_feedback_filename)
    unless File.exist?(old_autograde_feedback_path)
      return new_autograde_feedback_path
    end

    old_autograde_feedback_path
  end

  def create_user_directory_and_return_autograde_feedback_path
    create_user_handin_directory
    new_autograde_feedback_path
  end

  def autograde_file
    path = autograde_feedback_path
    return nil unless path

    if !File.exist?(path) || !File.readable?(path)
      nil
    else
      File.open path, "r"
    end
  end

  def handin_file
    path = handin_file_path
    return nil unless path

    if !File.exist?(path) || !File.readable?(path)
      nil
    else
      File.open path, "r"
    end
  end

  def annotated_file(file, filename, position)
    conditions = { filename: }
    conditions[:position] = position if position
    annotations = self.annotations.where(conditions)

    result = file.lines.map { |line| [line.force_encoding("UTF-8"), nil] }

    # annotation lines are one-indexed, so adjust for the zero-indexed array
    annotations.each do |a|
      # If a.line is nil, this becomes -1 so take max of this and 0
      idx = [a.line.to_i - 1, 0].max
      result[idx][1] = a
    end

    result
  end

  def user_and_assessment_in_same_course
    return if course_user_datum.course_id == assessment.course_id

    errors.add(:course_user_datum, "Invalid CourseUserDatum or Assessment")
  end

  def set_version
    self.submitted_by_id = course_user_datum_id unless submitted_by_id
    self.version = aud.update_version_number
  end

  def problems_to_scores
    p = {}
    assessment.problems.each { |problem| p[problem.id] = nil }
    scores.each { |score| p[score.problem_id] = score }
    p
  end

  def late_penalty(as_seen_by)
    late_penalty_opts(include_unreleased: !as_seen_by.student?)
  end

  def version_penalty(as_seen_by)
    version_penalty_opts(include_unreleased: !as_seen_by.student?)
  end

  # Number of days past user's due at
  #
  # 1. Look for possible extension
  # 2. If a student misses a deadline by less time that course.late_slack,
  #    consider them on time. e.g.: late_slack = 60 (seconds) and they turn in
  #    10 seconds *past* the first grace day, only one grace day would be used.
  #
  # Note: Return as soon as possible to prevent unnecessary object creation
  def days_late
    @days_late ||= days_late!
  end

  # Number of late days used on this submission for which you will be penalized
  def penalty_late_days
    @penalty_late_days ||= penalty_late_days!
  end

  # Number of grace days used on this submission
  def grace_days_used
    @grace_days_used ||= grace_days_used!
  end

  def final_score(as_seen_by)
    raise "FATAL: authorization error" if as_seen_by.student? && as_seen_by != course_user_datum

    o = {}
    o[:include_unreleased] = true unless as_seen_by.student?
    o[:untweaked] = true if as_seen_by.CA_only? # TODO: make this a policy option

    final_score_opts o
  end

  def all_scores_released?
    return false if scores.count != assessment.problems.count

    scores.inject(true) { |result, score| result and score.released? }
  end

  # NOTE: threshold  is no longer calculated using submission version,
  # but now using the number of submissions. This way, deleted submissions will
  # not be accounted for in the version penalty.
  def version_over_threshold_by
    # version threshold of -1 allows infinite submissions without penalty
    return 0 if assessment.effective_version_threshold < 0

    # normal submission versions start at 1
    # unofficial submissions conveniently have version 0
    # actual version number is not used here, instead submission count is used
    count = assessment.submissions.where(course_user_datum:).count
    [count - assessment.effective_version_threshold, 0].max
  end

  # Refer to https://github.com/autolab/autolab-src/wiki/Caching
  # NOTE: Remember to add invalidations if more options are added
  def invalidate_raw_score
    Submission.transaction do
      # acquire lock
      reload(lock: true)

      # invalidate
      Rails.cache.delete(raw_score_cache_key(include_unreleased: true))
      Rails.cache.delete(raw_score_cache_key(include_unreleased: false))
      # release lock
    end
  end

  # fall back to UA-reported mime_type, if not detected
  def detected_mime_type
    self[:detected_mime_type] || mime_type
  end

  # detect_mime_type - the mime_type field in a submission record is
  # not always accurate. This function uses the Linux file program
  # to determine the true mime type of a submission.
  def detect_mime_type
    # no file, no mime type
    return unless filename

    path = File.join(assessment.handin_directory_path, filename)
    file_output = `file -ib #{path}`
    self.detected_mime_type = file_output[%r{^(\w)+/([\w-])+}]
  end

  def syntax?
    !filename.nil?
  end

  def latest?
    (aud.latest_submission_id == id)
  end

  # override as_json to include the total with a parameter
  def as_json(options = {})
    json = super(options)
    json["total"] = final_score options[:seen_by]
    json["late_penalty"] = late_penalty options[:seen_by]
    json["grace_days_used"] = grace_days_used
    json["penalty_late_days"] = penalty_late_days
    json["days_late"] = days_late
    json["problems"] = assessment.problems
    json
  end

  def problems_released?
    scores.pluck(:released).all?
  end

  def grades_released?(as_seen_by)
    include_unreleased = as_seen_by.course_assistant? || as_seen_by.instructor?
    problems_released? || include_unreleased
  end

  # easy access to AUD
  def aud
    assessment.aud_for course_user_datum_id
  end

  def group_associated_submissions
    raise "Submission is not associated with a group" if group_key.empty?

    Submission.where(group_key:).where.not(id:)
  end

private

  # NOTE: remember to update cache_key if additional options are added
  def raw_score_cache_key(options)
    raw_score_base = "raw_score"
    raw_score_base << "_includes_unreleased" if options[:include_unreleased]

    "#{raw_score_base}/#{cache_key}/#{assessment.cache_key}"
  end

  def raw_score(options = {})
    @raw_score ||= {}
    @raw_score[options] ||= raw_score_cached options
  end

  def raw_score_cached(options = {})
    # 1. key-based invalidation occurs (the key changes hence invalidating the cache) when
    #    this submission, the assessment, its problems or its config file changes.
    #    see: http://37signals.com/svn/posts/3113-how-key-based-cache-expiration-works
    # 2. manual invalidation occurs when scores are updated
    #    see: https://github.com/autolab/autolab-src/wiki/Caching
    cache_key = raw_score_cache_key options
    unless (raw_score = Rails.cache.read cache_key)
      with_lock do
        # compute
        raw_score = raw_score! options

        # cache
        Rails.cache.write(cache_key, raw_score, expires_in: 7.days, race_condition_ttl: 1.minute)
      end
    end

    raw_score
  end

  # Returns a map from problem name (string) to score value (float)
  def raw_score_input(include_unreleased)
    v = {}

    # default score value is 0.0
    assessment.problems.each { |problem| v[problem.name] = 0.0 }

    # populate score values from scores
    problem_id_to_name = assessment.problem_id_to_name
    scores.each do |score|
      if score.score && (include_unreleased || score.released?)
        # will be a non-nil float
        v[problem_id_to_name[score.problem_id]] = score.score
      end
    end

    # guaranteed to be a problem name (string) => score value (float) hash
    v
  end

  # Returns a valid raw score (float) or throws an exception otherwise
  def raw_score!(options)
    scores = raw_score_input options[:include_unreleased]

    begin
      assessment.raw_score scores
    rescue ScoreComputationException => e
      errors[:base] << e.message
      raise e
    end
  end

  def late_penalty_opts(options = {})
    @late_penalty_opts ||= {}
    @late_penalty_opts[options] ||= late_penalty_opts! options
  end

  def version_penalty_opts(options = {})
    @version_penalty_opts ||= {}
    @version_penalty_opts[options] ||= version_penalty_opts! options
  end

  def final_score_opts(options = {})
    @final_score_opts ||= {}
    @final_score_opts[options] ||= final_score_opts! options
  end

  # Returns valid final_score (float)
  def final_score_opts!(options = {})
    include_unreleased_opt = { include_unreleased: options[:include_unreleased] }

    score = raw_score include_unreleased_opt
    score = apply_late_penalty(score, include_unreleased_opt)
    score = apply_version_penalty(score, include_unreleased_opt)
    apply_tweak score
  end

  def apply_late_penalty(value, include_unreleased_opt)
    [value - late_penalty_opts(include_unreleased_opt), 0].max
  end

  def apply_tweak(value)
    Tweak.apply_tweak(tweak, value)
  end

  def apply_version_penalty(value, include_unreleased_opt)
    [value - version_penalty_opts(include_unreleased_opt), 0].max
  end

  def allowed?
    submitted_at = created_at || Time.zone.now
    can, why_not = aud.can_submit? submitted_at, (submitted_by || course_user_datum)

    if can
      true
    else
      case why_not
      when :user_dropped
        errors.add(:base, "You cannot submit because you have dropped the course.")
      when :before_start_at
        errors.add(:base, "We are not yet accepting submissions on this assessment.")
      when :past_end_at
        errors.add(:base, "You cannot submit because it is past the deadline.")
      when :at_submission_limit
        errors.add(:base, "You have already reached the submission limit.")
      else
        raise "FATAL: unknown reason for submission denial"
      end
      false
    end
  end

  def penalty_late_days!
    days_late = self.days_late

    # grace_days_usable_by potentially expensive and most people aren't late
    if days_late == 0
      0
    else
      [days_late - aud.grace_days_usable, 0].max
    end
  end

  def grace_days_used!
    days_late = self.days_late

    # grace_days_usable_by potentially expensive and most people aren't late
    if days_late == 0
      0
    else
      [aud.grace_days_usable, days_late].min
    end
  end

  def days_late!
    # submissions for students who are Excused or Zeroed (for the assessment)
    # shouldn't be considered late
    return 0 if aud.grade_type != AssessmentUserDatum::NORMAL

    # optimization: without applying extension, etc. check if before due date
    return 0 if created_at <= assessment.due_at

    # check if no due at (due to infinite extension)
    return 0 unless aud.due_at

    # how late is the submission? (account for DST by offsetting difference in utc_offset)
    late_by = created_at - aud.due_at + (created_at.utc_offset - aud.due_at.utc_offset)
    return 0 if late_by <= 0

    # if you're 2.5 days late, you're 3 days late
    days_late = (late_by / 1.day).ceil

    # consider late slack
    days_late -= (late_by % 1.day) <= assessment.course.late_slack ? 1 : 0
    days_late
  end

  # Penalty incurred due to submitting late (after having used any grace days)
  #
  # Though this *is* what is displayed to the user, note that a lesser penalty
  # might *actually* be incurred if their raw_score is low enough. For example:
  #   raw_score = 10, late_penalty (this) = 15 => final_score = 0
  #
  # Also, note that percentage late penalties are applied to the *raw score*.
  # Thus, if assessment.late_penalty = 25pts, assessment.late_penalty = 20%,
  # and raw_score = 100, then final_score = 55. *Not* 80% * (100 - 25) or
  # (80% * 100) - 25 because the order of penalty application would then matter.
  def late_penalty_opts!(options = {})
    # if there is no late penalty policy (TODO: resolve this)
    return 0.0 if assessment.course.grace_days < 0

    # no penalty if no penalty late days used
    pld = penalty_late_days
    return 0.0 if pld == 0

    # otherwise, apply penalty
    daily_late_penalty = assessment.effective_late_penalty
    raw_score = raw_score options
    Penalty.applied_penalty(daily_late_penalty, raw_score, pld)
  end

  # Penalty incurred due to having submitted too many versions
  #
  # Though this *is* what is displayed to the user, note that a lesser penalty
  # might *actually* be incurred if their raw_score is low enough. For example:
  #   raw_score = 10, version_penalty (this) = 15 => final_score = 0
  #
  # Also, note that percentage version penalties are applied to the *raw score*.
  # Thus, if assessment.version_penalty = 25%, assessment.late_penalty = 20pts,
  # and raw_score = 100, then final_score = 55. *Not* 75% * (100 - 20) or
  # (75% * 100) - 20 because the order of penalty application would then matter.
  def version_penalty_opts!(options = {})
    # no version penalty policy
    return 0.0 unless assessment.version_penalty?

    # no penalty if version not over threshold
    votb = version_over_threshold_by
    return 0.0 if votb == 0

    # otherwise, apply penalty
    per_version_penalty = assessment.effective_version_penalty
    raw_score = raw_score options
    Penalty.applied_penalty(per_version_penalty, raw_score, votb)
  end

  include LatestSubmissionAssociationCache
end
