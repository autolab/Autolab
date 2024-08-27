require "association_cache"
require "fileutils"

class Course < ApplicationRecord
  trim_field :name, :semester, :display_name
  validates :name, uniqueness: { case_sensitive: false }
  validates :display_name, :start_date, :end_date, presence: true
  validates :late_slack, :grace_days, :late_penalty, :version_penalty, presence: true
  validates :grace_days, numericality: { greater_than_or_equal_to: 0 }
  validates :version_threshold, numericality: { only_integer: true, greater_than_or_equal_to: -1 }
  validate :order_of_dates
  validate :valid_name?, on: :create
  # validates course website format if there exists one
  validate :valid_website?
  validates :access_code, uniqueness: true, allow_nil: true

  has_many :course_user_data, dependent: :destroy
  has_many :assessments, dependent: :destroy
  has_many :scheduler, dependent: :destroy

  has_many :announcements, dependent: :destroy
  has_many :attachments, dependent: :destroy
  belongs_to :late_penalty, class_name: "Penalty"
  belongs_to :version_penalty, class_name: "Penalty"
  has_many :assessment_user_data, through: :assessments
  has_many :submissions, through: :assessments
  has_many :watchlist_instances, dependent: :destroy
  has_many :risk_conditions, dependent: :destroy
  has_one :watchlist_configuration, dependent: :destroy
  has_one :lti_course_datum, dependent: :destroy

  # Callbacks
  before_save :cgdub_dependencies_updated, if: :grace_days_or_late_slack_changed?
  before_create :cgdub_dependencies_updated
  after_create :init_course_folder

  # Constants
  VALID_CODE_REGEX = /\A[A-Z0-9]{6}\z/ # String is transformed to uppercase
  VALID_CODE_REGEX_HTML = "[a-zA-Z0-9]{6}".freeze # For use in HTML

  # Misc.
  accepts_nested_attributes_for :late_penalty, :version_penalty

  def config_file_path
    Rails.root.join("courseConfig", "#{sanitized_name}.rb")
  end

  def config_backup_file_path
    config_file_path.sub_ext(".rb.bak")
  end

  def directory_path
    Rails.root.join("courses", name)
  end

  # Create a course with name, semester, and instructor email
  # all other fields are filled in automatically
  def self.quick_create(unique_name, semester, instructor_email)
    newCourse = Course.new(name: unique_name, semester:)
    newCourse.display_name = newCourse.name

    # fill temporary values in other fields
    newCourse.late_slack = 0
    newCourse.grace_days = 0
    newCourse.start_date = Time.current
    newCourse.end_date = Time.current

    newCourse.late_penalty = Penalty.new
    newCourse.late_penalty.kind = "points"
    newCourse.late_penalty.value = "0"

    newCourse.version_penalty = Penalty.new
    newCourse.version_penalty.kind = "points"
    newCourse.version_penalty.value = "0"

    unless newCourse.save
      raise "Failed to create course #{newCourse.name}: "\
            "#{newCourse.errors.full_messages.join(', ')}"
    end

    # Check instructor
    instructor = User.where(email: instructor_email).first
    # create a new user as instructor if didn't exist
    if instructor.nil?
      begin
        instructor = User.instructor_create(instructor_email,
                                            newCourse.name)
      rescue StandardError => e
        # roll back course creation
        newCourse.destroy
        raise "Failed to create instructor for course: #{e}"
      end
    end

    # Create CUD
    newCUD = newCourse.course_user_data.new
    newCUD.user = instructor
    newCUD.instructor = true
    unless newCUD.save
      # roll back course creation
      newCourse.destroy
      raise "Failed to create CUD for instructor of new course #{newCourse.name}"
    end

    # Load course config
    begin
      newCourse.reload_course_config
    rescue StandardError, SyntaxError
      # roll back course and CUD creation
      newCUD.destroy
      newCourse.destroy
    end

    newCourse
  end

  # generate course folder
  def init_course_folder
    dir_path = directory_path
    FileUtils.mkdir_p dir_path

    FileUtils.touch File.join(dir_path, "autolab.log")

    course_rb = File.join(dir_path, "course.rb")

    # rubocop:disable Rails/FilePath
    default_course_rb = Rails.root.join("lib", "__defaultCourse.rb")
    # rubocop:enable Rails/FilePath

    FileUtils.cp default_course_rb, course_rb

    FileUtils.mkdir_p Rails.root.join("assessmentConfig")
    FileUtils.mkdir_p Rails.root.join("courseConfig")
  end

  def order_of_dates
    return if start_date.nil? || end_date.nil?

    errors.add(:start_date, "must come before end date") if start_date > end_date
  end

  def valid_name?
    if /\A(\w|-)+\z/.match?(name)
      true
    else
      suggest_name = name.gsub(/(\s+)/) { '-' }
      suggest_name = suggest_name.gsub(/([^\w-]+)/) { '' }
      name_error = if !suggest_name.empty?
                     "cannot include characters other than alphanumeric characters, hyphens, "\
                       "and underscores. Suggestion: #{suggest_name}"
                   else
                     "cannot include characters other than alphanumeric characters, hyphens, "\
                       "and underscores."
                   end
      errors.add("name", name_error)
      false
    end
  end

  def valid_website?
    if website.nil? || website.eql?("")
      true
    elsif website[0..7].eql?("https://")
      true
    else
      errors.add("website", "needs to start with https://")
      false
    end
  end

  def temporal_status(now = DateTime.now)
    if now < start_date
      :upcoming
    elsif now > end_date
      if disable_on_end
        :disabled
      else
        :completed
      end
    else
      :current
    end
  end

  def is_disabled?
    disabled? or (disable_on_end? && DateTime.now > end_date)
  end

  def current_assessments(now = DateTime.now)
    assessments.where("start_at < :now AND end_at > :now", now:)
  end

  def full_name
    if !semester.to_s.empty?
      "#{display_name} (#{semester})"
    else
      display_name
    end
  end

  def source_config_file_path
    Rails.root.join("courses", name, "course.rb")
  end

  def reload_config_file
    s = File.open(source_config_file_path, "r")
    lines = s.readlines
    s.close

    # read from source
    config_source = File.open(source_config_file_path, "r", &:read)

    # validate syntax of config
    RubyVM::InstructionSequence.compile(config_source)

    # backup old config
    if File.exist? config_file_path
      File.rename(config_file_path, config_backup_file_path)
    end

    d = File.open(config_file_path, "w")
    d.write("require 'CourseBase.rb'\n\n")
    d.write("module #{config_module_name}\n")
    d.write("\tinclude CourseBase\n\n")
    lines.each do |line|
      if !line.empty?
        d.write("\t#{line}")
      else
        d.write(line)
      end
    end
    d.write("end")
    d.close

    load(config_file_path)
    # rubocop:disable Security/Eval
    eval(config_module_name)
    # rubocop:enable Security/Eval
  end

  # reload_course_config
  # Reload the course config file and extend the loaded methods
  # to AdminsController
  def reload_course_config
    mod = reload_config_file

    AdminsController.extend(mod)
  end

  def sanitized_name
    name.gsub(/[^A-Za-z0-9]/, "")
  end

  def invalidate_cgdubs
    cgdub_dependencies_updated
    save!
  end

  # NOTE: Needs to be updated as new items are cached
  def invalidate_caches
    # cgdubs
    invalidate_cgdubs

    # raw_scores
    # NOTE: keep in sync with assessment#invalidate_raw_scores
    # rubocop:disable Rails/SkipsModelValidations
    assessments.update_all(updated_at: Time.current)
    # rubocop:enable Rails/SkipsModelValidations
  end

  def config
    @config ||= config!
  end

  # return all CUDs that are not course_assistants, instructors, or dropped
  # TODO: should probably exclude adminstrators, but the fact that admins are in
  #   the User model instead of CourseUserDatum makes that difficult
  def students
    course_user_data.where(course_assistant: false, instructor: false, dropped: [false, nil])
  end

  # return all CUDs that are not course_assistants, instructors, or dropped
  def instructors
    course_user_data.where(instructor: true)
  end

  def assessment_categories
    assessments.unscope(:order).distinct.pluck(:category_name).sort
  end

  def assessments_with_category(cat_name, is_student = false)
    if is_student
      assessments.where(category_name: cat_name).ordered.released
    else
      assessments.where(category_name: cat_name).ordered
    end
  end

  def to_param
    name
  end

  def asmts_before_date(date)
    asmts = assessments.ordered
    asmts.where("due_at < ?", date)
  end

  def exclude_curr_asmts(asmts)
    date = DateTime.current
    asmts.reject do |asmt|
      asmt.due_at > date
    end
  end

  # Used by manage extensions, create submission, and sudo
  def get_autocomplete_data
    users = {}
    usersEncoded = {}
    course_user_data.each do |cud|
      # Escape once here, and another time in _autocomplete.html.erb (see comments)
      users[CGI.escapeHTML cud.full_name_with_email] = cud.id
      # base64 to avoid issues where leading / trailing whitespaces are stripped (see #931)
      # strict_encode64 to avoid line feeds
      usersEncoded[Base64.strict_encode64(cud.full_name_with_email.strip).strip] = cud.id
    end
    [users, usersEncoded]
  end

  # To determine if a course assistant has permission to watchlist
  def watchlist_allow_ca
    return false if watchlist_configuration.nil?

    watchlist_configuration.allow_ca
  end

  def dump_yaml(include_metrics)
    YAML.dump(serialize(include_metrics))
  end

  def generate_tar(export_configs)
    base_path = Rails.root.join("courses", name).to_s
    course_dir = name
    rb_path = "course.rb"
    config_path = "#{name}.yml"
    mode = 0o755

    begin
      tarStream = StringIO.new("")
      Gem::Package::TarWriter.new(tarStream) do |tar|
        tar.mkdir course_dir, File.stat(base_path).mode

        # save course.rb
        source_file = File.open(File.join(base_path, rb_path), 'rb')
        tar.add_file File.join(course_dir, rb_path), File.stat(source_file).mode do |tar_file|
          tar_file.write(source_file.read)
        end
        source_file.close

        # save course and metrics config
        tar.add_file File.join(course_dir, config_path), mode do |tar_file|
          tar_file.write(dump_yaml(export_configs&.include?('metrics_config')))
        end

        # save assessments
        if export_configs&.include?('assessments')
          assessments.each do |assessment|
            asmt_dir = assessment.name
            assessment.dump_yaml
            filter = [assessment.handin_directory_path]
            assessment.load_dir_to_tar(base_path, asmt_dir, tar, filter, course_dir)
          end
        end
      end
      tarStream.rewind
      tarStream.close
      tarStream
    end
  end

private

  def saved_change_to_grade_related_fields?
    saved_change_to_late_slack? or saved_change_to_grace_days? or
      saved_change_to_version_threshold? or saved_change_to_late_penalty_id? or
      saved_change_to_version_penalty_id?
  end

  def grace_days_or_late_slack_changed?
    grace_days_changed? or late_slack_changed?
  end

  def saved_change_to_grace_days_or_late_slack?
    saved_change_to_grace_days? or saved_change_to_late_slack?
  end

  def cgdub_dependencies_updated
    self.cgdub_dependencies_updated_at = Time.current
  end

  def config!
    source = "#{name}_course_config".to_sym
    Utilities.execute_instructor_code(source) do
      require config_file_path
      # rubocop:disable Security/Eval
      Class.new.extend eval(config_module_name)
      # rubocop:enable Security/Eval
    end
  end

  def config_module_name
    "Course#{sanitized_name.camelize}"
  end

  def serialize(include_metrics)
    s = {}
    s["general"] = serialize_general
    s["general"]["late_penalty"] = late_penalty.serialize unless late_penalty.nil?
    s["general"]["version_penalty"] = version_penalty.serialize unless version_penalty.nil?
    s["attachments"] = attachments.map(&:serialize) if attachments.exists?

    if include_metrics
      if risk_conditions.exists?
        s["risk_conditions"] = risk_conditions.map(&:serialize)
        latest_version = risk_conditions.order(version: :desc).first.version
        s["risk_conditions"] = risk_conditions.where(version: latest_version).map(&:serialize)
      end

      if watchlist_configuration.present?
        s["watchlist_configuration"] =
          watchlist_configuration.serialize
      end
    end
    s
  end

  GENERAL_SERIALIZABLE = Set.new %w[name semester late_slack grace_days display_name start_date
                                    end_date disabled exam_in_progress version_threshold
                                    gb_message website disable_on_end]
  def serialize_general
    Utilities.serializable attributes, GENERAL_SERIALIZABLE
  end

  include CourseAssociationCache
end
