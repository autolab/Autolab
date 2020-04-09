require "association_cache"
require "fileutils"
require "utilities"

class Assessment < ApplicationRecord
  # Mass-assignment
  # attr_protected :name

  # Associations
  belongs_to :course
  belongs_to :course_user_datum
  belongs_to :late_penalty, class_name: "Penalty"
  belongs_to :version_penalty, class_name: "Penalty"
  has_many :submissions
  has_many :problems, dependent: :destroy
  has_many :extensions, dependent: :destroy
  has_many :attachments
  has_many :assessment_user_data, dependent: :destroy
  has_one :autograder, dependent: :destroy
  has_one :scoreboard, dependent: :destroy

  # Validations
  validates_uniqueness_of :name, scope: :course_id
  validates :name, format: { with: /\A[^0-9].*/, message: "can't have leading numeral" }
  validates_length_of :display_name, minimum: 1
  validate :verify_dates_order
  validate :handin_directory_and_filename_or_disable_handins, if: :active?
  validate :handin_directory_exists_or_disable_handins, if: :active?
  validates_numericality_of :max_size, :max_submissions
  validates_numericality_of :version_threshold, only_integer: true,
                                                greater_than_or_equal_to: -1, allow_nil: true
  validates_numericality_of :max_grace_days, only_integer: true,
                                             greater_than_or_equal_to: 0, allow_nil: true
  validates_numericality_of :group_size, only_integer: true, greater_than_or_equal_to: 1, allow_nil: true
  validates_presence_of :name, :display_name, :due_at, :end_at, :start_at,
                        :grading_deadline, :category_name, :max_size, :max_submissions

  # Callbacks
  trim_field :name, :display_name, :handin_filename, :handin_directory, :handout, :writeup
  after_save :dump_yaml
  after_save :invalidate_course_cgdubs, if: :due_at_changed?
  after_save :invalidate_course_cgdubs, if: :max_grace_days_changed?
  after_create :create_AUDs_modulo_callbacks

  # Constants
  ORDERING = "due_at ASC, name ASC"
  RELEASED = "start_at < ?"

  # Scopes
  scope :ordered, -> { order(ORDERING) }
  scope :released, ->(as_of = Time.now) { where(RELEASED, as_of) }
  scope :unreleased, ->(as_of = Time.now) { where.not(RELEASED, as_of) }

  # Misc.
  accepts_nested_attributes_for :late_penalty, :version_penalty, allow_destroy: true

  # Need to create AUDs for all users when new assessment is created
  #
  # Also used by populator (in autolab.rake) to populate AUD.latest_submission
  def create_AUDs_modulo_callbacks
    course.course_user_data.find_each do |cud|
      AssessmentUserDatum.create_modulo_callbacks(assessment_id: id,
                                                  course_user_datum_id: cud.id)
    end
  end

  # Used by populator (in autolab.rake) to update AUD.latest_submission
  #
  # Can be used manually if AUD.latest_submission goes out of sync (emergency!)
  def update_latest_submissions_modulo_callbacks
    calculate_latest_submissions.each do |s|
      AssessmentUserDatum.where(assessment_id: id, course_user_datum_id: s.course_user_datum_id)
        .update_all(latest_submission_id: s.id)
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

  def getLanguages
      return self.languages.split(/\s*,\s*/)
  end

  def getTextfields
      return self.textfields.split(/\s*,\s*/)
  end

  def folder_path
    Rails.root.join("courses", course.name, name)
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

  def latest_submission_by(cud)
    assessment_user_data.find_by(course_user_datum: cud).latest_submission
  end

  def config_file_path
    Rails.root.join("assessmentConfig", "#{course.name}-#{sanitized_name}.rb")
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

  def construct_folder
    # this should construct the assessment folder and the handin folder
    FileUtils.mkdir_p(handin_directory_path)
    dump_yaml if construct_default_config_file
  end

  ##
  # Gives the assessment a default config file, unless it already has a config file.
  # returns true if the file is actually created
  #
  def construct_default_config_file
    assessment_config_file_path = source_config_file_path
    return false if File.file?(assessment_config_file_path)

    # Open and read the default assessment config file
    default_config_file_path = Rails.root.join("lib", "__defaultAssessment.rb")
    config_source = File.open(default_config_file_path, "r") { |f| f.read }

    # Update with this assessment information
    config_source.gsub!("##NAME_CAMEL##", name.camelize)
    config_source.gsub!("##NAME_LOWER##", name)

    # Write the new config out to the right file.
    File.open(assessment_config_file_path, "w") { |f| f.write(config_source) }
    # Load the assessment config file while we're at it
    File.open(config_file_path, "w") { |f| f.write config_source }

    true
  end

  ##
  # Copies an assessment's config file to the RAILS_ROOT/assessmentConfig folder.
  # Renames the module to include the course name so that the files have unique module names.
  #
  # WILL NOT WORK ON NEW, UNSAVED ASSESSMENTS!!!
  #
  def load_config_file
    # read from source
    config_source = File.open(source_config_file_path, "r") { |f| f.read }

    # uniquely rename module (so that it's unique among all assessment modules loaded in Autolab)
    config = config_source.gsub("module #{source_config_module_name}",
                                "module #{config_module_name}")

    # write to config_file_path
    File.open(config_file_path, "w") { |f| f.write config }

    # config file might have an updated custom raw score function: clear raw score cache
    invalidate_raw_scores

    logger.info "Loaded #{config_file_path}"
  end

  def config_module
    # (re)construct config file from source, unless it already exists
    load_config_file unless File.exist? config_file_path

    # (re)load config file if it was updated or wasn't ever loaded into this process
    reload_config_file if config_file_updated?

    # return config module
    eval config_module_name
  end

  ##
  # writes the properties of the assessment in YAML format to the assessment's yaml file
  #
  def dump_yaml
    File.open(path("#{name}.yml"), "w") { |f| f.write(YAML.dump serialize) }
  end

  ##
  # reads from the properties of the YAML file and saves them to the assessment.
  # Will only run if the assessment has not been saved.
  #
  def load_yaml
    return unless new_record?
    props = YAML.load(File.open(path("#{name}.yml"), "r") { |f| f.read })
    backwards_compatibility(props)
    deserialize(props)
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
      raw_score = Utilities.execute_instructor_code(:raw_score) do
        config.raw_score scores
      end
      Utilities.validated_score_value(raw_score, :raw_score)
    else
      score_values = scores.values.map(&:to_f)
      score_values.reduce(0, :+)
    end
  end

  def overwrites_method?(methodKey)
    config_module.instance_methods.include?(methodKey)
  end

  def has_autograder?
    autograder != nil
  end

  def has_groups?
    group_size && group_size > 1
  end

  def has_scoreboard?
    scoreboard != nil
  end

  def groups
    Group.joins(:assessment_user_data).where(assessment_user_data: { assessment_id: id }).distinct
  end

  def grouplessCUDs
    course.course_user_data.joins(:assessment_user_data).where(assessment_user_data: { assessment_id: id, membership_status: AssessmentUserDatum::UNCONFIRMED })
  end

  def to_param
    name
  end

private

  def path(filename)
    Rails.root.join("courses", course.name, name, filename)
  end

  def source_config_file_path
    Rails.root.join("courses", course.name, sanitized_name, "#{sanitized_name}.rb")
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
    submissions.group(:course_user_datum_id).having("MAX(submissions.version)")
  end

  def invalidate_course_cgdubs
    course.invalidate_cgdubs
  end

  def config!
    source = "#{name}_assessment_config".to_sym
    Utilities.execute_instructor_code(source) do
      Class.new.extend config_module
    end
  end

  def serialize
    s = {}
    s["general"] = serialize_general
    s["problems"] = problems.map(&:serialize)
    s["autograder"] = autograder.serialize if has_autograder?
    s["scoreboard"] = scoreboard.serialize if has_scoreboard?
    s["late_penalty"] = late_penalty.serialize if late_penalty
    s["version_penalty"] = version_penalty.serialize if version_penalty
    s
  end

  GENERAL_SERIALIZABLE = Set.new %w(name display_name category_name description handin_filename handin_directory has_svn has_lang max_grace_days handout writeup max_submissions disable_handins max_size version_threshold)

  def serialize_general
    Utilities.serializable attributes, GENERAL_SERIALIZABLE
  end

  def deserialize(s)
    self.due_at = self.end_at = self.visible_at = self.start_at = self.grading_deadline = Time.now
    self.quiz = false
    self.quizData = ""
    update!(s["general"])
    Problem.deserialize_list(self, s["problems"]) if s["problems"]
    if s["autograder"]
      Autograder.find_or_initialize_by(assessment_id: id).update(s["autograder"])
    end
    if s["scoreboard"]
      Scoreboard.find_or_initialize_by(assessment_id: id).update(s["scoreboard"])
    end
    if s["late_penalty"]
      late_penalty ||= Penalty.new
      late_penalty.update(s["late_penalty"])
    end
    if s["version_penalty"]
      version_penalty ||= Penalty.new
      version_penalty.update(s["version_penalty"])
    end
  end

  def default_max_score
    problems.sum :max_score
  end

  def max_score!
    if config.respond_to? :max_score
      v = Utilities.execute_instructor_code(:max_score) do
        config.max_score
      end
      Utilities.validated_score_value(v, :max_score)
    else
      default_max_score
    end
  end

  def is_file?(name)
    !name.blank? && File.file?(path name)
  end

  def verify_dates_order
    errors.add :due_at, "must be after the start date" if start_at > due_at
    errors.add :end_at, "must be after the due date" if due_at > end_at
    errors.add :grading_deadline, "must be after the end date" if end_at > grading_deadline
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
    return true if disable_handins?

    dir = handin_directory_path
    return true if File.directory? dir

    begin
      Dir.mkdir dir
    rescue SystemCallError => e
      errors.add :handin_directory, "(#{dir}) could not be created, please do so manually. (#{e})"
      false
    else
      true
    end
  end

  def invalidate_raw_scores
    # key-based invalidation (see submission.raw_score)
    touch
  end

  def sanitized_name
    name.gsub(/\./, "")
  end

  def active?
    Time.now <= course.end_date
  end

  ##
  # This function attempts to preserve Backwords Compatibility for when assessments are
  # imported from a YAML file
  #
  GENERAL_BC = { "category" => "category_name",
                 "handout_filename" => "handout",
                 "writeup_filename" => "writeup",
                 "has_autograde" => nil,
                 "has_scoreboard" => nil }
  BACKWORDS_COMPATIBILITY = { "autograding_setup" => "autograder",
                              "scoreboard_setup" => "scoreboard" }
  def backwards_compatibility(props)
    GENERAL_BC.each do |old, new|
      next unless props["general"].key?(old)
      props["general"][new] = props["general"][old] unless new.nil?
      props["general"].delete(old)
    end
    BACKWORDS_COMPATIBILITY.each do |old, new|
      next unless props.key?(old)
      props[new] = props[old]
      props.delete(old)
    end
    props["general"]["category_name"] ||= "General"
  end

  include AssessmentAssociationCache
end
