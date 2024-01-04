require "association_cache"

class CourseUserDatum < ApplicationRecord
  class AuthenticationFailed < RuntimeError
    attr_reader :user_message, :dev_message

    # rubocop:disable Lint/MissingSuper
    def initialize(user_message, dev_message)
      @user_message = user_message
      @dev_message = dev_message
    end
    # rubocop:enable Lint/MissingSuper
  end

  AUTH_LEVELS = %i[student course_assistant instructor administrator].freeze

  # Don't want to trim the nickname.
  trim_field :school, :major, :year, :lecture, :section, :grade_policy, :email

  belongs_to :course
  belongs_to :user
  belongs_to :tweak, class_name: "Tweak"
  has_many :submissions, dependent: :destroy
  has_many :extensions, dependent: :destroy
  has_many :scores, through: :submissions
  has_many :assessment_user_data, dependent: :destroy
  has_many :watchlist_instances, dependent: :destroy

  attr_readonly :course_id
  before_save :strip_html
  accepts_nested_attributes_for :tweak, allow_destroy: true
  accepts_nested_attributes_for :user, allow_destroy: false
  validate :valid_nickname?
  after_create :create_AUDs_modulo_callbacks

  def self.conditions_by_like(value, *columns)
    columns = self.columns if columns.empty?
    columns = columns[0] if columns[0].is_a?(Array)
    # rubocop:disable Lint/UselessAssignment
    conditions = columns.map do |c|
      c = c.name if c.is_a? ActiveRecord::ConnectionAdapters::Column
      "`#{c}` LIKE " + ActiveRecord::Base.connection.quote("%#{value}%")
    end.join(" OR ")
    # rubocop:enable Lint/UselessAssignment
  end

  def strip_html
    CourseUserDatum.content_columns.each do |column|
      next unless column.type == :string || column.type == :text

      self[column.name] = self[column.name].gsub(/</, "") unless self[column.name].nil?
    end
  end

  def after_create
    COURSE_LOGGER.log("CourseUserDatum CREATED for #{user.email}:" \
      "{#{nickname},#{major},#{lecture},#{section}}")
  end

  def after_update
    COURSE_LOGGER.log("CourseUserDatum UPDATED for #{user.email}:" \
      "{#{nickname},#{major},#{lecture},#{section}}")
  end

  def valid_nickname?
    return if nickname.nil?

    if nickname.length > 32
      errors.add("nickname", "is too long (maximum is 32 characters)")
    end

    return if nickname.ascii_only?

    errors.add("nickname", "can only contain ASCII characters")
  end

  ##
  # HELPER ALIASES
  ##
  delegate :full_name, to: :user

  delegate :full_name_with_email, to: :user

  delegate :display_name, to: :user

  ##
  # END HELPER ALIASES
  ##

  def can_sudo?
    user.administrator? || instructor?
  end

  def can_sudo_to?(cud)
    if user.administrator?
      true
    elsif instructor? && !cud.user.administrator? &&
          course == cud.course
      true
    else
      false
    end
  end

  def student?
    !(instructor? || course_assistant?)
  end

  def CA_of?(student)
    return false unless course_assistant?
    return false unless student.student?

    section == student.section && lecture == student.lecture
  end

  def instructor_of?(student)
    return false unless instructor?
    return false unless student.student?

    course == student.course
  end

  # because CAs can do things that instructors can't as of 2/19/2013
  # e.g.: CAs can release (their) section grades, instructors can't
  def CA_only?
    course_assistant? && !instructor?
  end

  def can_administer?(student)
    user.administrator? || instructor_of?(student) || CA_of?(student)
  end

  def average(as_seen_by)
    @average ||= {}
    @average[as_seen_by] ||= average! as_seen_by
  end

  def category_average(category, as_seen_by)
    @category_average ||= {}
    @category_average[category] ||= {}
    @category_average[category][as_seen_by] ||= category_average! category, as_seen_by
  end

  def has_auth_level?(level)
    case level
    when :administrator
      user.administrator?
    when :instructor
      instructor? || user.administrator?
    when :course_assistant
      course_assistant? || instructor? || user.administrator?
    when :student
      true
    else
      false
    end
  end

  def auth_level_string
    if instructor?
      "instructor"
    elsif course_assistant?
      "course_assistant"
    else
      "student"
    end
  end

  def global_grace_days_left
    return @ggl if @ggl

    cache_key = ggl_cache_key

    unless (ggl = Rails.cache.read cache_key)
      CourseUserDatum.transaction do
        # acquire lock on CUD
        reload(lock: true)

        ggl = global_grace_days_left!

        Rails.cache.write(ggl_cache_key, ggl, expires_in: 7.days, race_condition_ttl: 1.minute)
        # release lock
      end
    end

    @ggl = ggl
  end

  #
  # User Attribute Wrappers - these functions get attributes from the CUD's
  #   associated User object, in an attempt to hide the User object
  #

  delegate :administrator?, to: :user

  delegate :email, to: :user

  delegate :first_name, to: :user

  delegate :last_name, to: :user

  delegate :major, to: :user

  delegate :school, to: :user

  delegate :year, to: :user

  # find a cud in the course
  def self.find_cud_for_course(course, uid)
    user = User.find(uid)
    cud = user.course_user_data.find_by(course:)
    if cud.nil?
      if user.administrator?
        new_cud = course.course_user_data.new(user:,
                                              instructor: true,
                                              course_assistant: true)
        new_cud.save ? new_cud : nil
      end
    else
      cud
    end
  end

  # find a cud in the course, or create one using
  # user's info if he's an admin
  def self.find_or_create_cud_for_course(course, uid)
    user = User.find(uid)

    cud = user.course_user_data.find_by(course:)

    if cud
      [cud, :found]
    elsif user.administrator?
      new_cud = course.course_user_data.new(user:,
                                            instructor: true,
                                            course_assistant: true)

      new_cud.save ? [new_cud, :admin_created] : [nil, :admin_creation_error]

    else
      [nil, :unauthorized]
    end
  end

  # global grace left cache key
  def ggl_cache_key
    # gets it into the YYYYMMDDHHMMSS form
    dua = course.cgdub_dependencies_updated_at.utc.to_s(:number)

    "ggl/dua-#{dua}/u-#{id}"
  end

private

  # Need to create AUDs for all assessments when new user is created
  def create_AUDs_modulo_callbacks
    course.assessments.find_each do |asmt|
      AssessmentUserDatum.create_modulo_callbacks(assessment_id: asmt.id,
                                                  course_user_datum_id: id)
      # TODO: which id?
    end
  end

  def average!(as_seen_by)
    input = average_input as_seen_by
    v = Utilities.execute_instructor_code(:courseAverage) do
      course.config.courseAverage input
    end
    avg = Utilities.validated_score_value(v, :courseAverage, true)

    # apply tweak
    Tweak.apply_tweak tweak, avg
  end

  def category_average!(category, as_seen_by)
    input = category_average_input(category, as_seen_by)
    method_name = "#{category}Average".to_sym

    config = course.config
    if config.respond_to? method_name
      v = Utilities.execute_instructor_code(method_name) do
        config.send method_name, input
      end
      Utilities.validated_score_value(v, method_name, true)
    else
      default_category_average input
    end
  end

  def default_category_average(input)
    final_scores = input.values
    final_scores.reduce(:+) / final_scores.size if !final_scores.empty?
  end

  def category_average_input(category, as_seen_by)
    @category_average_input ||= {}
    @category_average_input[as_seen_by] ||= {}
    input = (@category_average_input[as_seen_by][category] ||= {})

    # rubocop:disable Lint/UselessAssignment
    user_id = id
    # rubocop:enable Lint/UselessAssignment
    course.assessments.each do |a|
      next unless a.category_name == category

      input[a.name] ||= a.aud_for(id).final_score as_seen_by
    end

    # remove nil computed scores -- instructors shouldn't have to deal with nils
    compact_hash input
  end

  def average_input(as_seen_by)
    @average_input ||= {}
    input = (@average_input[as_seen_by] ||= {})

    # rubocop:disable Lint/UselessAssignment
    user_id = id
    # rubocop:enable Lint/UselessAssignment
    course.assessments.each do |a|
      input[a.name] ||= a.aud_for(id).final_score as_seen_by
    end

    course.assessment_categories.each do |cat|
      input["cat#{cat}"] ||= category_average cat, as_seen_by
    end

    # remove nil computed scores -- instructors shouldn't have to deal with nils
    compact_hash input
  end

  def compact_hash(hash)
    hash.delete_if { |_, v| !v }
  end

  def global_grace_days_left!
    latest_asmt = course.assessments.ordered.last

    if latest_asmt.nil?
      # Just don't cache anything since no database query is necessary
      course.grace_days
    else
      # do the usual database query and calculate
      cur_aud = AssessmentUserDatum.get(latest_asmt.id, id)
      return course.grace_days if cur_aud.nil?

      (course.grace_days - cur_aud.global_cumulative_grace_days_used)
    end
  end

  include CUDAssociationCache
end
