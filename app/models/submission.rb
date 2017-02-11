require "utilities"
require "association_cache"
require "json"
##
# Submissions jointly belong to Assessments and CourseUserData
#
class Submission < ActiveRecord::Base
  attr_accessor :lang, :formfield1, :formfield2, :formfield3
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
  validates :version, uniqueness: { scope: [:course_user_datum_id, :assessment_id] }
  validate :user_and_assessment_in_same_course

  has_many :annotations, dependent: :destroy

  before_save :detect_mime_type
  before_destroy :archive_handin
  before_validation :set_version, on: :create

  # keep track of latest submission
  after_save :update_latest_submission, if: :version_changed?
  after_save :update_latest_submission, if: :ignored_changed?
  after_save do |sub|
    COURSE_LOGGER.log("Submission #{sub.id} SAVED for " \
      "#{sub.course_user_datum.user.email} on" \
      " #{sub.assessment.name}, file #{sub.filename} (#{sub.mime_type}),"\
      "version: #{sub.version}")
  end

  after_create :update_latest_submission
  after_destroy :update_latest_submission

  # allow stuff to get updated by mass assign
  # attr_accessible :notes, :tweak_attributes

  # latest (unignored) submissions
  scope :latest, -> { joins(:assessment_user_datum).joins(:course_user_datum) }

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

  def save_file(upload)
    filename = course_user_datum.user.email + "_" +
               version.to_s + "_" +
               assessment.handin_filename
    directory = assessment.handin_directory
    path = File.join(Rails.root, "courses",
                     course_user_datum.course.name,
                     assessment.name, directory, filename)

    if upload["file"]
      # Sanity!
      upload["file"].rewind
      File.open(path, "wb") { |f| f.write(upload["file"].read) }
    elsif upload["local_submit_file"]
      # local_submit_file is a path string to the temporary handin
      # directory we create for local submissions
      File.open(path, "wb") { |f| f.write(IO.read(upload["local_submit_file"], mode: File::RDONLY|File::NOFOLLOW)) }
    elsif upload["tar"]
      src = upload["tar"]
      `mv #{src} #{path}`
    end

    self.filename = filename

    if upload["file"]
      begin
        self.mime_type = upload["file"].content_type
      rescue
        self.mime_type = nil
      end
      self.mime_type = "text/plain" unless mime_type
    elsif upload["local_submit_file"]
      self.mime_type = "text/plain"
    elsif upload["tar"]
      self.mime_type = "application/x-tgz"
    end
    save_additional_form_fields(upload)
    self.save!
    settings_file = course_user_datum.user.email + "_" +
               version.to_s + "_" + assessment.handin_filename +
               ".settings.json"

		settings_path = File.join(Rails.root, "courses",
                     course_user_datum.course.name,
                     assessment.name, directory, settings_file)

		File.open(settings_path, "wb") { |f| f.write(self.settings) }
  end

  def save_additional_form_fields(params)
      form_hash = Hash.new
      if params["lang"]
          form_hash["Language"] = params["lang"]
      end
      if params["formfield1"]
          form_hash[assessment.getTextfields[0]] = params["formfield1"]
      end
      if params["formfield2"]
          form_hash[assessment.getTextfields[1]] = params["formfield2"]
      end
      if params["formfield3"]
          form_hash[assessment.getTextfields[2]] = params["formfield3"]
      end
      self.settings = form_hash.to_json
      self.save!
  end

  def getSettings
      if self.settings
          return JSON.parse(self.settings)
      else
          return Hash.new
      end
  end

  def archive_handin
    return if assessment.disable_handins
    return if filename.nil?
    return unless File.exist?(handin_file_path)

    archive = File.join(assessment.handin_directory_path, "archive")
    Dir.mkdir(archive) unless FileTest.directory?(archive)

    # Using the id instead of the version guarentees a unique filename
    submission_backup = File.join(archive, "deleted_#{filename}")
    FileUtils.mv(handin_file_path, submission_backup)

    archive_autograder_feedback(archive)
  end

  def archive_autograder_feedback(archive)
    return unless assessment.has_autograder?
    feedback_path = autograde_feedback_path
    return unless File.exist?(feedback_path)

    backup = File.join(archive, "deleted_#{autograde_feedback_filename}")
    FileUtils.mv(feedback_path, backup)
  end

  def handin_file_path
    return nil unless filename
    File.join(assessment.handin_directory_path, filename)
  end

  def handin_annotated_file_path
    return nil unless filename
    File.join(assessment.handin_directory_path, "annotated_#{filename}")
  end

  def autograde_feedback_filename
    "#{course_user_datum.email}_#{version}_#{assessment.name}_autograde.txt"
  end

  def autograde_feedback_path
    File.join(assessment.handin_directory_path, autograde_feedback_filename)
  end

  def handin_file
    path = handin_file_path
    return nil unless path
    if !File.exist?(path) || !File.readable?(path)
      return nil
    else
      return File.open path, "r"
    end
  end

  def annotated_file(file, filename, position)
    conditions = { filename: filename }
    conditions[:position] = position if position
    annotations = self.annotations.where(conditions)

    result = file.lines.map { |line| [line.force_encoding("UTF-8"), nil] }

    # annotation lines are one-indexed, so adjust for the zero-indexed array
    annotations.each { |a| result[a.line - 1][1] = a }

    result
  end

  def user_and_assessment_in_same_course
    return if (course_user_datum.course_id == assessment.course_id)
    errors.add(:course_user_datum, "Invalid CourseUserDatum or Assessment")
  end

  def set_version
    self.submitted_by_id = course_user_datum_id unless submitted_by_id
    begin
      if version != 0
        self.version = 1 + assessment.submissions.where(course_user_datum:
          course_user_datum).maximum(:version)
      end
    rescue TypeError
      self.version = 1
    end
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
    fail "FATAL: authorization error" if as_seen_by.student? && as_seen_by != course_user_datum

    o = {}
    o[:include_unreleased] = true unless as_seen_by.student?
    o[:untweaked] = true if as_seen_by.CA_only? # TODO: make this a policy option

    final_score_opts o
  end

  def version_over_threshold_by
    # version threshold of -1 allows infinite submissions without penalty
    return 0 if assessment.effective_version_threshold < 0

    # normal submission versions start at 1
    # unofficial submissions conveniently have version 0
    [version - assessment.effective_version_threshold, 0].max
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
    end # release lock
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
    self.detected_mime_type = file_output[/^(\w)+\/([\w-])+/]
  end

  def syntax?
    !filename.nil?
  end

  def latest?
    (aud.latest_submission_id == id)
  end

  # override as_json to include the total with a paramter
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

  def grading_complete?(as_seen_by)
    include_unreleased = !as_seen_by.student?

    complete, released = scores_status
    (released || include_unreleased) && complete
  end

  def scores_status
    all_complete, all_released = true, true

    problems_to_scores.each do |problem, score|
      next if problem.optional?
      return false unless score
      all_complete &&= false unless score.score
      all_released &&= score.released?
    end

    [all_complete, all_released]
  end

  # easy access to AUD
  def aud
    assessment.aud_for course_user_datum_id
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
        Rails.cache.write(cache_key, raw_score)
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
    score = apply_tweak score
    score
  end

  def apply_late_penalty(v, include_unreleased_opt)
    [v - late_penalty_opts(include_unreleased_opt), 0].max
  end

  def apply_tweak(v)
    Tweak.apply_tweak(tweak, v)
  end

  def apply_version_penalty(v, include_unreleased_opt)
    [v - version_penalty_opts(include_unreleased_opt), 0].max
  end

  def allowed?
    submitted_at = created_at || Time.now
    can, why_not = aud.can_submit? submitted_at, (submitted_by || course_user_datum)

    if can
      true
    else
      case why_not
      when :user_dropped
        errors[:base] << "You cannot submit because you have dropped the course."
      when :before_start_at
        errors[:base] << "We are not yet accepting submissions on this assessment."
      when :past_end_at
        errors[:base] << "You cannot submit because it is past the deadline."
      when :at_submission_limit
        errors[:base] << "You you have already reached the submission limit."
      else
        fail "FATAL: unknown reason for submission denial"
      end
      false
    end
  end

  def penalty_late_days!
    days_late = self.days_late

    # grace_days_usable_by potentially expensive and most people aren't late
    if (days_late == 0)
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

    # how late is the submission?
    late_by = created_at - aud.due_at
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
