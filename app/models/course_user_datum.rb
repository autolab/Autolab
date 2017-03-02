require "association_cache"

class CourseUserDatum < ActiveRecord::Base
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
    average = if config.respond_to? method_name
                v = Utilities.execute_instructor_code(method_name) do
                  config.send method_name, input
                end
                Utilities.validated_score_value(v, method_name, true)
              else
                default_category_average input
    end

    average
  end

  def default_category_average(input)
    final_scores = input.values
    if final_scores.size > 0
      final_scores.reduce(:+) / final_scores.size
    else
      nil
    end
  end

  def category_average_input(category, as_seen_by)
    @category_average_input ||= {}
    @category_average_input[as_seen_by] ||= {}
    input = (@category_average_input[as_seen_by][category] ||= {})

    user_id = id
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

    user_id = id
    course.assessments.each do |a|
      input[a.name] ||= a.aud_for(id).final_score as_seen_by
    end

    course.assessment_categories.each do |cat|
      input["cat#{cat}"] ||= category_average cat, as_seen_by
    end

    # remove nil computed scores -- instructors shouldn't have to deal with nils
    compact_hash input
  end

  def compact_hash(h)
    h.delete_if { |_, v| !v }
  end

  include CUDAssociationCache
end
