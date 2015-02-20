require 'utilities'
require 'association_cache'

class Assessment < ActiveRecord::Base
  # Mass-assignment
  # attr_protected :name

  # Associations
  belongs_to :course
  belongs_to :course_user_datum
  belongs_to :late_penalty, :class_name => "Penalty"
  belongs_to :version_penalty, :class_name => "Penalty"
  has_many :submissions
  has_many :problems, :dependent => :destroy
  has_many :extensions, :dependent => :destroy
  has_many :attachments
  has_many :assessment_user_data, :dependent => :destroy
  has_one :autograding_setup, :dependent => :destroy
  has_one :scoreboard_setup, :dependent => :destroy

  # Validations
  validates_uniqueness_of :name, :scope => :course_id
  validates_length_of :display_name, :minimum => 1
  validate :verify_dates_order
  validate :handin_directory_and_filename_or_disable_handins, :if => :active?
  validate :handin_directory_exists_or_disable_handins, :if => :active?
  validates_numericality_of :max_size, :max_submissions
  validates_numericality_of :version_threshold, :only_integer => true,
                            :greater_than_or_equal_to => -1, :allow_nil => true
  validates_numericality_of :max_grace_days, :only_integer => true,
                            :greater_than_or_equal_to => 0, :allow_nil => true
  validates_numericality_of :group_size, only_integer: true, greater_than_or_equal_to: 1, allow_nil: true
  validates_presence_of :name, :display_name, :due_at, :end_at, :start_at,
                        :grading_deadline, :category_name, :max_size, :max_submissions

  # Callbacks
  trim_field :name, :display_name, :handin_filename, :handin_directory, :handout, :writeup
  after_save :invalidate_course_cgdubs, :if => :due_at_changed?
  after_save :invalidate_course_cgdubs, :if => :max_grace_days_changed?
  after_create :create_AUDs_modulo_callbacks

  # Constants
  ORDERING = "due_at ASC, name ASC"
  RELEASED = "start_at < ?"

  # Scopes
  scope :ordered, -> { order(ORDERING) }
  scope :released, ->(as_of = Time.now) { where(RELEASED, as_of) }
  scope :unreleased, ->(as_of = Time.now) { where.not(RELEASED, as_of) }

  # Misc.
  accepts_nested_attributes_for :late_penalty, :version_penalty, :allow_destroy => true

  # Need to create AUDs for all users when new assessment is created
  #
  # Also used by populator (in autolab.rake) to populate AUD.latest_submission
  def create_AUDs_modulo_callbacks
    course.course_user_data.find_each { |cud|
      AssessmentUserDatum.create_modulo_callbacks({ :assessment_id => id, 
                                                    :course_user_datum_id => cud.id })
    }
  end

  # Used by populator (in autolab.rake) to update AUD.latest_submission
  #
  # Can be used manually if AUD.latest_submission goes out of sync (emergency!)
  def update_latest_submissions_modulo_callbacks
    calculate_latest_submissions.each do |s|
      AssessmentUserDatum.where({ :assessment_id => id, :course_user_datum_id => s.course_user_datum_id })
                         .update_all({ :latest_submission_id => s.id })
    end
  end

  # Uniquely identify the previous assessment
  #
  # This gives assessments a defined ordering, required for grace day calculations.
  def assessment_before
    sorted_asmts = course.assessments.ordered
    self_index = sorted_asmts.index self
    self_index > 0 ? sorted_asmts[self_index - 1] : nil
  end

  def before_grading_deadline?
    Time.now <= grading_deadline
  end

  def handout_path
    path handout
  end

  def handin_directory_path
    path handin_directory
  end

  def writeup_path
    path writeup
  end

  def released?(as_of = Time.now)
    start_at < as_of
  end

  # { problem_id => problem_name } mapping for all problems associated with this assessment
  def problem_id_to_name
    problem_id_to_name = {}
    problems.each { |problem| problem_id_to_name[problem.id] = problem.name }
    problem_id_to_name
  end

  def latest_submission_by cud
    assessment_user_data.where(:course_user_datum => cud).first.latest_submission
  end

  def config_file_path
    File.join Rails.root, "assessmentConfig", "#{course.name}-#{sanitized_name}.rb"
  end

  def config_module_name
    (sanitized_name + course.sanitized_name).camelize
  end 

  def config
    @config ||= config!
  end

  # Late penalty for this assessment
  #
  # Use default course late penalty, if not set
  def effective_late_penalty
    late_penalty || course.late_penalty
  end

  # Penalty to apply per version past the version_threshold
  def effective_version_penalty 
    version_penalty || course.version_penalty
  end

  # Submission version number past which to start applying version penalty
  #
  # Since version numbers are start at 1, a version_threshold of 0 would mean 
  # that all versions > 0 would be penalized. Since versions start at 1, this
  # means that all versions are penalized.
  def effective_version_threshold
    version_threshold || course.version_threshold
  end

  # Checks if a version penalty needs to be applied
  #
  # If version_threshold == -1 (i.e. unlimited submissions without penalty)
  # or version_penalty == 0.0, no version penalty needs to be applied.
  def version_penalty?
    effective_version_threshold > -1 && effective_version_penalty.value != 0.0
  end

  def aud_for(cud_id)
    assessment_user_data.find_by course_user_datum_id: cud_id
  end

  def max_score
    @max_score ||= max_score!
  end

  def construct_config_file
    # read from source
    source_config_file = File.open source_config_file_path, "r"
    source_config = source_config_file.read
    source_config_file.close

    # uniquely rename module (so that it's unique among all assessment modules loaded in Autolab)
    config = source_config.gsub "module #{source_config_module_name}", "module #{config_module_name}"

    # write to config_file_path
    config_file = File.open config_file_path, "w"
    config_file.write config
    config_file.close

    # config file might have an updated custom raw score function: clear raw score cache
    invalidate_raw_scores

    logger.info "Constructed #{config_file_path}"
  end

  def config_module
    # (re)construct config file from source, unless it already exists
    construct_config_file unless File.exists? config_file_path

    # (re)load config file if it was updated or wasn't ever loaded into this process
    reload_config_file if config_file_updated?

    # return config module
    eval config_module_name
  end

  def settings_yaml_path
    path "#{name}.yml"
  end

  def serialize_yaml_to_path path
    yaml = YAML.dump serialize
    File.open(path, 'w') { |f| f.puts yaml }
  end

  def writeup_is_url?
    Utilities.is_url? writeup
  end

  def writeup_is_file?
    is_file? writeup
  end

  def handout_is_url?
    Utilities.is_url? handout
  end

  def handout_is_file?
    is_file? handout
  end

  # raw_score
  # @param map of problem names to problem scores 
  # @return score on this assignment not including any tweak or late penalty.
  # We generically cast all values to floating point numbers because we don't
  # trust the upstream developer to do that for us. 
  def raw_score(scores)
    if config.respond_to? :raw_score
      raw_score = Utilities.execute_instructor_code(:raw_score) {
        config.raw_score scores
      }
      Utilities.validated_score_value(raw_score, :raw_score)
    else
      score_values = scores.values.map { |score| score.to_f() }
      score_values.reduce(0, :+)
    end
  end

  def overwrites_method?(methodKey)
    self.config_module.instance_methods.include?(methodKey)
  end

  def has_groups?
    group_size && group_size > 1
  end
  
  def groups
    Group.joins(:assessment_user_data).where(assessment_user_data: {assessment_id: self.id}).distinct
  end
  
  def grouplessCUDs
    self.course.course_user_data.joins(:assessment_user_data).where(assessment_user_data: {assessment_id: self.id, membership_status: AssessmentUserDatum::UNCONFIRMED})
  end

private
  def path filename
    File.join Rails.root, 'courses', course.name, name, filename
  end

  def source_config_file_path
    File.join Rails.root, "courses", course.name, sanitized_name, "#{sanitized_name}.rb"
  end

  def source_config_module_name
    sanitized_name.camelize
  end

  @@CONFIG_FILE_LAST_LOADED = {}

  def reload_config_file
    # remove the previously loaded config module
    Object.send :remove_const, config_module_name if Object.const_defined? config_module_name

    # force load config file (see http://www.ruby-doc.org/core-2.0.0/Kernel.html#method-i-load)
    load config_file_path

    # updated last loaded time
    @@CONFIG_FILE_LAST_LOADED[config_file_path] = Time.now

    logger.info "Reloaded #{config_file_path}"
  end

  def config_file_updated?
    # config file last modified time
    config_file_mtime = File.mtime config_file_path

    # get last loaded time of config file by this process
    last_loaded_time = @@CONFIG_FILE_LAST_LOADED[config_file_path]

    # if there isn't last loaded time, consider config file updated
    last_loaded_time ? config_file_mtime >= last_loaded_time : true
  end

  # Manually calculate most recent unignored submission for each user for this assessment
  #
  # NOTE: Must be kept in sync with AUD.latest_submission!
  def calculate_latest_submissions
    max_version_subquery = "SELECT * FROM (SELECT MAX(version), course_user_datum_id
                            FROM `submissions`
                            WHERE assessment_id = #{id} AND ignored = FALSE
                            GROUP BY course_user_datum_id) AS x"
    Submission.select("submissions.*").where("(version, course_user_datum_id) IN (#{max_version_subquery}) AND assessment_id = ?", id)
  end

  def invalidate_course_cgdubs
    course.invalidate_cgdubs
  end

  def config!
    source = "#{name}_assessment_config".to_sym
    Utilities.execute_instructor_code(source) {
      Class.new.extend config_module
    }
  end

  def serialize
    s = {}
    s["general"] = serialize_general
    s["problems"] = problems.map &:serialize
    s["autograding_setup"] = autograding_setup.serialize if autograding_setup
    s["scoreboard_setup"] = scoreboard_setup.serialize if scoreboard_setup
    s
  end

  GENERAL_SERIALIZABLE = Set.new [ "name", "display_name", "description", "handin_filename", "handin_directory",
                           "has_autograde", "has_svn", "has_scoreboard",
                           "max_grace_days", "handout", "writeup", "max_submissions",
                           "disable_handins", "max_size" ]

  def serialize_general
    Utilities.serializable attributes, GENERAL_SERIALIZABLE
  end

  def deserialize s
    attributes = s["general"] if s["general"]
    problems = Problem.deserialize_list s["problems"] if s["problems"]
    autograding_setup = AutogradingSetup.deserialize s["autograding_setup"] if s["autograding_setup"]
    scoreboard_setup = ScoreboardSetup.deserialize s["autograding_setup"] if s["scoreboard_setup"]
  end

  def default_max_score
    problems.sum :max_score
  end

  def max_score!
    if config.respond_to? :max_score
      v = Utilities.execute_instructor_code(:max_score) {
        config.max_score
      }
      Utilities.validated_score_value(v, :max_score)
    else
      default_max_score
    end
  end

  def is_file? name
    !name.blank? && File.file?(path name)
  end

  def verify_dates_order
    errors.add :start_at, "must be before time assessment is due at" if start_at > due_at
    errors.add :due_at, "must be before time assessment ends at" if due_at > end_at
  end

  def handin_directory_and_filename_or_disable_handins
    if disable_handins?
      true
    else
      d = handin_directory.blank?
      f = handin_filename.blank?

      errors.add :handin_directory, "must be specified when handins are enabled" if d
      errors.add :handin_filename, "must be specified when handins are enabled" if f

      !(d || f)
    end
  end 

  def handin_directory_exists_or_disable_handins
    if disable_handins?
      true
    else
      dir = handin_directory_path
      if File.directory? dir
        true
      else
        begin
          Dir.mkdir dir
        rescue SystemCallError => e
          errors.add :handin_directory, "(#{dir}) could not be created, please do so manually. (#{e})"
          false
        else
          true
        end
      end
    end
  end

  def invalidate_raw_scores
    # key-based invalidation (see submission.raw_score)
    touch
  end

  def sanitized_name
    name.gsub(/\./, '')
  end

  def active?
    Time.now <= course.end_date
  end

  include AssessmentAssociationCache
end
