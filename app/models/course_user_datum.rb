require "association_cache"

class CourseUserDatum < ApplicationRecord
  class AuthenticationFailed < Exception
    attr_reader :user_message, :dev_message
    def initialize(user_message, dev_message)
      @user_message = user_message
      @dev_message = dev_message
    end
  end

  AUTH_LEVELS = [:student, :course_assistant, :instructor, :administrator]

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
    columns = self.columns if columns.size == 0
    columns = columns[0] if columns[0].is_a?(Array)
    conditions = columns.map do|c|
      c = c.name if c.is_a? ActiveRecord::ConnectionAdapters::Column
      "`#{c}` LIKE " + ActiveRecord::Base.connection.quote("%#{value}%")
    end.join(" OR ")
  end

  def strip_html
    for column in CourseUserDatum.content_columns
      if column.type == :string || column.type == :text
        unless self[column.name].nil?
          self[column.name] = self[column.name].gsub(/</, "")
        end
      end
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
    if !nickname
      true
    elsif nickname.length > 32
      errors.add("nickname", "is too long (maximum is 32 characters)")
      false
    elsif !nickname.ascii_only?
      errors.add("nickname", "can only contain ASCII characters")
      false
    else
      true
    end
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
      return true
    elsif instructor? && !cud.user.administrator? &&
          course == cud.course
      return true
    else
      return false
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
    course_assistant? && (!instructor?)
  end

  def can_administer?(student)
    user.administrator? || instructor_of?(student) || CA_of?(student)
  end

  # now we're storing a hash instead of a scalar...
  def aggregate_hash(as_seen_by)
    @aggregate ||= {}
    @aggregate[as_seen_by] ||= aggregate_hash! as_seen_by
  end

  # now we're storing a hash per category instead of a scalar...
  def category_aggregate_hash(category, as_seen_by)
    @category_aggregate_hash ||= {}
    @category_aggregate_hash[category] ||= {}
    @category_aggregate_hash[category][as_seen_by] ||= category_aggregate_hash! category, as_seen_by
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
      return "instructor"
    elsif course_assistant?
      return "course_assistant"
    else
      return "student"
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

        Rails.cache.write(ggl_cache_key, ggl)
      end # release lock
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
    cud = user.course_user_data.find_by(course: course)
    if cud.nil?
      if user.administrator?
        new_cud = course.course_user_data.new(user: user,
                                              instructor: true,
                                              course_assistant: true)
        return new_cud.save ? new_cud : nil
      end
    else
        return cud
    end
  end

  # find a cud in the course, or create one using
  # user's info if he's an admin
  def self.find_or_create_cud_for_course(course, uid)
    user = User.find(uid)

    cud = user.course_user_data.find_by(course: course)

    if cud
      return [cud, :found]
    else
      if user.administrator?

        new_cud = course.course_user_data.new(user: user,
                                              instructor: true,
                                              course_assistant: true)

        return new_cud.save ? [new_cud, :admin_created] : [nil, :admin_creation_error]
      else
        return [nil, :unauthorized]
      end
    end
  end

  # global grace left cache key
  def ggl_cache_key
    # gets it into the YYYYMMDDHHMMSS form
    dua = course.cgdub_dependencies_updated_at.utc.to_s(:number)

    "ggl/dua-#{dua}/u-#{self.id}"
  end

  # This method call is used specifically for the purpose of callback style update to watchlist
  # Need to archive old instances and also add new instances
  def update_cud_gdu_watchlist_instances
    # At this point, all relevant previously cached grace day usage information should be invalidated
    # Calls to calculate grace day usage should be from scratch
    WatchlistInstance.update_cud_gdu_watchlist_instances(self)
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

  def aggregate_hash!(as_seen_by)

    config = course.config
    agghash = if config.respond_to? :courseAggregate
                inputs = aggregate_inputs as_seen_by
                v = Utilities.execute_instructor_code(:courseAggregate) do
                  config.courseAggregate inputs[0], inputs[1]
                end
                Utilities.validated_score_hash(v, :courseAggregate, true)
	      else # backward compatibility
                input = aggregate_input as_seen_by
                avg = Utilities.execute_instructor_code(:courseAverage) do
                  config.courseAverage input
                end
                v = {:name => "Average", :value => avg}
                Utilities.validated_score_hash(v, :courseAggregate, true)
              end
    # apply tweak
    agghash[:value] = Tweak.apply_tweak tweak, agghash[:value]
    agghash
  end

  def category_aggregate_hash!(category, as_seen_by)
    input = category_aggregate_input(category, as_seen_by)
    method_name = "#{category}Aggregate".to_sym
    old_method_name = "#{category}Average".to_sym  # backward compatibility

    config = course.config
    agghash = if config.respond_to? method_name
                v = Utilities.execute_instructor_code(method_name) do
                  config.send method_name, input
                end
                Utilities.validated_score_hash(v, method_name, true)
              elsif config.respond_to? old_method_name
                avg = Utilities.execute_instructor_code(old_method_name) do
                  config.send old_method_name, input
                end
                v = {name: "Average", value: avg}
                Utilities.validated_score_hash(v, method_name, true)
              else
                v = Utilities.execute_instructor_code(:defaultCategoryAggregate) do
                  config.send :defaultCategoryAggregate, input
                end
                Utilities.validated_score_hash(v, :defaultCategoryAggregate, true)

    end

    agghash
  end

  def category_aggregate_input(category, as_seen_by)
    @category_aggregate_input ||= {}
    @category_aggregate_input[as_seen_by] ||= {}
    input = (@category_aggregate_input[as_seen_by][category] ||= {})

    user_id = id
    course.assessments.each do |a|
      next unless a.category_name == category
      input[a.name] ||= a.aud_for(id).final_score as_seen_by
    end

    # remove nil computed scores -- instructors shouldn't have to deal with nils
    compact_hash input
  end

  def aggregate_input(as_seen_by)
    @aggregate_input ||= {}
    input = (@aggregate_input[as_seen_by] ||= {})

    user_id = id
    course.assessments.each do |a|
      input[a.name] ||= a.aud_for(id).final_score as_seen_by
    end

    course.assessment_categories.each do |cat|
      input["cat#{cat}"] ||= category_aggregate_hash(cat, as_seen_by)[:value]
    end

    Rails.logger.info("**SWLOG** Getting aggregate input: #{input}")
    # remove nil computed scores -- instructors shouldn't have to deal with nils
    compact_hash input

  end

  # new version of aggregate_input, returns list of two hashes
  # assessment scores and category aggregates to avoid name collisions
  def aggregate_inputs(as_seen_by)
    @newstyle_aggregate_input ||= {}
    inputs = (@newstyle_aggregate_input[as_seen_by] ||= [{}, {}])

    user_id = id
    course.assessments.each do |a|
      inputs[0][a.name] ||= a.aud_for(id).final_score as_seen_by
    end

    course.assessment_categories.each do |cat|
      # here, we don't use the 'cat' prefix, since we'll pass these separately
      inputs[1]["#{cat}"] ||= category_aggregate_hash(cat, as_seen_by)[:value]
    end

    # remove nil computed scores -- instructors shouldn't have to deal with nils
    compact_hash inputs[0]
    compact_hash inputs[1]

    inputs
  end

  def compact_hash(h)
    h.delete_if { |_, v| !v }
  end

  def global_grace_days_left!
    latest_asmt = course.assessments.ordered.last

    if latest_asmt.nil?
      # Just don't cache anything since no database query is necessary
      return course.grace_days
    else
      # do the usual database query and calculate
      cur_aud = AssessmentUserDatum.get(latest_asmt.id, self.id)
      return course.grace_days if cur_aud.nil?
      return (course.grace_days - cur_aud.global_cumulative_grace_days_used)
    end
  end

  include CUDAssociationCache
end
