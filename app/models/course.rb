require "association_cache"
require "fileutils"

class Course < ActiveRecord::Base
  trim_field :name, :semester, :display_name
  validates_uniqueness_of :name
  validates_presence_of :display_name, :start_date, :end_date
  validates_presence_of :late_slack, :grace_days, :late_penalty, :version_penalty
  validates_numericality_of :grace_days, greater_than_or_equal_to: 0
  validates_numericality_of :version_threshold, only_integer: true, greater_than_or_equal_to: -1
  validate :order_of_dates

  has_many :course_user_data, dependent: :destroy
  has_many :assessments, dependent: :destroy
  has_many :scheduler, dependent: :destroy

  has_many :announcements, dependent: :destroy
  has_many :attachments, dependent: :destroy
  belongs_to :late_penalty, class_name: "Penalty"
  belongs_to :version_penalty, class_name: "Penalty"
  has_many :assessment_user_data, through: :assessments
  has_many :submissions, through: :assessments

  accepts_nested_attributes_for :late_penalty, :version_penalty

  before_save :cgdub_dependencies_updated, if: :grace_days_changed?
  before_save :cgdub_dependencies_updated, if: :late_slack_changed?
  before_create :cgdub_dependencies_updated
  after_create :init_course_folder

  # generate course folder
  def init_course_folder
    course_dir = Rails.root.join("courses", name)
    FileUtils.mkdir_p course_dir

    FileUtils.touch File.join(course_dir, "autolab.log")

    course_rb = File.join(course_dir, "course.rb")
    default_course_rb = Rails.root.join("lib", "__defaultCourse.rb")
    FileUtils.cp default_course_rb, course_rb

    FileUtils.mkdir_p Rails.root.join("assessmentConfig")
    FileUtils.mkdir_p Rails.root.join("courseConfig")
    FileUtils.mkdir_p Rails.root.join("gradebooks")
  end

  def order_of_dates
    errors.add(:start_date, "must come before end date") if start_date > end_date
  end

  def temporal_status(now = DateTime.now)
    if now < start_date
      :upcoming
    elsif now > end_date
      :completed
    else
      :current
    end
  end

  def current_assessments(now = DateTime.now)
    assessments.where("start_at < :now AND end_at > :now", now: now)
  end

  def full_name
    if semester.to_s.size > 0
      display_name + " (" + semester + ")"
    else
      display_name
    end
  end

  def reload_config_file
    course = name.gsub(/[^A-Za-z0-9]/, "")
    src = Rails.root.join("courses", name, "course.rb")
    dest = Rails.root.join("courseConfig/", "#{course}.rb")
    s = File.open(src, "r")
    lines = s.readlines
    s.close

    d = File.open(dest, "w")
    d.write("require 'CourseBase.rb'\n\n")
    d.write("module Course" + course.camelize + "\n")
    d.write("\tinclude CourseBase\n\n")
    for line in lines do
      if line.length > 0
        d.write("\t" + line)
      else
        d.write(line)
      end
    end
    d.write("end")
    d.close

    load(dest)
    eval("Course#{course.camelize}")
  end

  # reload_course_config
  # Reload the course config file and extend the loaded methods
  # to AdminsController
  def reload_course_config
    mod = nil
    begin
      mod = reload_config_file
    rescue Exception => @error
      return false
    end

    AdminsController.extend(mod)
    true
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
    assessments.update_all(updated_at: Time.now)
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
    assessments.pluck("DISTINCT category_name").sort
  end

  def assessments_with_category(cat_name, isStudent = false)
    if isStudent
      assessments.where(category_name: cat_name).ordered.released
    else
      assessments.where(category_name: cat_name).ordered
    end
  end

  def to_param
    name
  end

private

  def cgdub_dependencies_updated
    self.cgdub_dependencies_updated_at = Time.now
  end

  def config!
    source = "#{name}_course_config".to_sym
    Utilities.execute_instructor_code(source) do
      require config_file_path
      Class.new.extend eval(config_module_name)
    end
  end

  def config_file_path
    Rails.root.join("courseConfig", "#{sanitized_name}.rb")
  end

  def config_module_name
    "Course#{sanitized_name.camelize}"
  end

  include CourseAssociationCache
end
