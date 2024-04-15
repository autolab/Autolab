require "archive"
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
  validates :name, uniqueness: { case_sensitive: false, scope: :course_id }
  validates :name, format: { with: /\A[^0-9].*/, message: "can't have leading numeral" }
  validates :display_name, length: { minimum: 1 }
  validate :verify_dates_order
  validate :handin_directory_and_filename_or_disable_handins, if: :active?
  validate :handin_directory_exists_or_disable_handins, if: :active?
  validate :valid_handout
  validate :valid_writeup
  validate :valid_handin_directory
  validates :max_size, :max_submissions, numericality: true
  validates :version_threshold, numericality: { only_integer: true,
                                                greater_than_or_equal_to: -1, allow_nil: true }
  validates :max_grace_days, numericality: { only_integer: true,
                                             greater_than_or_equal_to: 0, allow_nil: true }
  validates :group_size, numericality: { only_integer: true, greater_than_or_equal_to: 1,
                                         allow_nil: true }
  validates :name, :display_name, :due_at, :end_at, :start_at,
            :category_name, :max_size, :max_submissions, presence: true

  # Callbacks
  trim_field :name, :display_name, :handin_filename, :handin_directory, :handout, :writeup
  after_commit :dump_yaml
  after_commit :dump_embedded_quiz, if: :saved_change_to_embedded_quiz_form_data?
  after_save :invalidate_course_cgdubs, if: :saved_change_to_due_at_or_max_grace_days?
  after_create :create_AUDs_modulo_callbacks

  # Constants
  ORDERING = "due_at ASC, name ASC".freeze
  RELEASED = "start_at < ?".freeze
  VALID_NAME_REGEX = /^[A-Za-z][A-Za-z0-9_-]*$/
  VALID_NAME_SANITIZER_REGEX = /^[^A-Za-z]*([A-Za-z0-9_-]+)/
  # Scopes
  scope :ordered, -> { order(ORDERING) }
  scope :released, ->(as_of = Time.current) { where(RELEASED, as_of) }
  scope :unreleased, ->(as_of = Time.current) { where.not(RELEASED, as_of) }

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
    # rubocop:disable Rails/SkipsModelValidations
    calculate_latest_submissions.each do |s|
      AssessmentUserDatum.where(assessment_id: id, course_user_datum_id: s.course_user_datum_id)
                         .update_all(latest_submission_id: s.id)
    end
    # rubocop:enable Rails/SkipsModelValidations
  end

  # Uniquely identify the previous assessment
  #
  # This gives assessments a defined ordering, required for grace day calculations.
  def assessment_before
    sorted_asmts = course.assessments.ordered
    self_index = sorted_asmts.index self
    self_index > 0 ? sorted_asmts[self_index - 1] : nil
  end

  def folder_path
    Rails.root.join("courses", course.name, name)
  end

  def asmt_yaml_path
    path "#{name}.yml"
  end

  def handout_path
    path handout
  end

  def handin_directory_path
    path handin_directory
  end

  def log_path
    path "log.txt"
  end

  def writeup_path
    path writeup
  end

  def released?(as_of = Time.current)
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

  def unique_config_file_path
    Rails.root.join("assessmentConfig", "#{course.name}-#{name}-#{id}.rb")
  end

  def config_backup_file_path
    config_file_path.sub_ext(".rb.bak")
  end

  def unique_config_backup_file_path
    unique_config_file_path.sub_ext(".rb.bak")
  end

  def config_module_name
    (sanitized_name + course.sanitized_name).camelize
  end

  def unique_config_module_name
    "#{sanitized_name}#{id}".camelize
  end

  def use_unique_module_name
    File.exist? unique_config_file_path
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
    effective_version_threshold > -1 && effective_version_penalty.value.to_d != 0.0.to_d
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
    constructed_default_config_file = construct_default_config_file
    if constructed_default_config_file
      dump_yaml
    end
    constructed_default_config_file
  end

  ##
  # Gives the assessment a default config file, unless it already has a config file.
  # returns true if the file is actually created
  #
  def construct_default_config_file
    assessment_config_file_path = unique_source_config_file_path
    return false if File.file?(assessment_config_file_path)

    # Open and read the default assessment config file
    default_config_file_path = Rails.root.join("lib/__defaultAssessment.rb")
    config_source = File.open(default_config_file_path, "r", &:read)

    # Update with this assessment information
    config_source.gsub!("##NAME_CAMEL##", unique_config_module_name)
    # Write the new config out to the right file.
    File.open(assessment_config_file_path, "w") { |f| f.write(config_source) }
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
    config_source = File.open(unique_source_config_file_path, "r", &:read)

    # validate syntax of config
    begin
      RubyVM::InstructionSequence.compile(config_source)
    rescue SyntaxError => e
      raise StandardError, e
    end

    # ensure source_config_module_name is an actual module in the assessment config rb file
    # otherwise loading the file on subsequent calls to config_module will result in an exception

    # uniquely rename module (so that it's unique among all assessment modules loaded in Autolab)
    if config_source !~ /\b#{unique_config_module_name}\b/
      match = config_source.match(/module\s+(\w+)/)
      if match.nil?
        # no module found in the source, so we will add a template config to assessmentConfig
        # (assuming that there is no important code, since there isn't even a module)

        # Open and read the default assessment config file, fill in with assessment name
        default_config_file_path = Rails.root.join("lib/__defaultAssessment.rb")
        config_source = File.open(default_config_file_path, "r", &:read)
        config_source.gsub!("##NAME_CAMEL##", unique_config_module_name)
      else
        config_source = config_source.sub(match[0], "module #{unique_config_module_name}")
      end
    end

    # backup old *unique* configs
    # we keep the previous config_file_path, if it exists, to allow for the unique file path changes
    # to be reverted without breaking all previous existing assessments
    if File.exist?(unique_config_file_path)
      File.rename(unique_config_file_path, unique_config_backup_file_path)
    end

    # write to config_file_path
    File.open(unique_config_file_path, "w") { |f| f.write config_source }

    # config file might have an updated custom raw score function: clear raw score cache
    invalidate_raw_scores
    dump_yaml
    logger.info "Loaded #{unique_config_file_path}"
  end

  def config_module
    # (re)construct config file from source, unless it already exists
    load_config_file unless File.exist? unique_config_file_path

    # (re)load config file if it was updated or wasn't ever loaded into this process
    reload_config_file if config_file_updated?

    # return config module

    # rubocop:disable Security/Eval
    eval unique_config_module_name
    # rubocop:enable Security/Eval
  end

  ##
  # writes the properties of the assessment in YAML format to the assessment's yaml file
  #
  def dump_yaml
    File.open(asmt_yaml_path, "w") { |f| f.write(YAML.dump(sort_hash(serialize))) }
  end

  ##
  # reads from the properties of the YAML file and saves them to the assessment.
  # Will only run if the assessment has not been saved.
  #
  def load_yaml
    return unless new_record?

    props = YAML.safe_load(File.open(asmt_yaml_path, "r", &:read))
    backwards_compatibility(props)
    deserialize(props)
  end

  def writeup_is_url?
    Utilities.is_url? writeup
  end

  def writeup_is_file?
    # Ensure that writeup lies within the assessment folder
    writeup.present? && Archive.in_dir?(writeup_path, folder_path) && is_file?(writeup)
  end

  def handout_is_url?
    Utilities.is_url? handout
  end

  def handout_is_file?
    # Ensure that handout lies within the assessment folder
    handout.present? && Archive.in_dir?(handout_path, folder_path) && is_file?(handout)
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

  def assessment_variable
    return {} unless config_module.instance_methods.include?(:assessmentVariables)

    config_module.assessmentVariables
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

  def has_writeup?
    writeup_is_url? || writeup_is_file?
  end

  def has_handout?
    overwrites_method?(:handout) || handout_is_url? || handout_is_file?
  end

  def groups(show_members: false)
    if show_members
      Group.includes(assessment_user_data: { course_user_datum: :user })
           .where(assessment_user_data: { assessment_id: id })
    else
      Group.joins(:assessment_user_data).where(assessment_user_data: { assessment_id: id }).distinct
    end
  end

  def grouplessCUDs
    course.course_user_data.joins(:assessment_user_data).
      where(assessment_user_data: {
              assessment_id: id,
              membership_status: AssessmentUserDatum::UNCONFIRMED
            })
  end

  def to_param
    name
  end

  def dump_embedded_quiz
    return unless embedded_quiz

    File.open(path("#{name}_embedded_quiz.html"), "w") { |f| f.write(embedded_quiz_form_data) }
  end

  def load_embedded_quiz
    return unless embedded_quiz && File.file?(path("#{name}_embedded_quiz.html"))

    quiz = File.open(path("#{name}_embedded_quiz.html"), "r", &:read)
    update(embedded_quiz_form_data: quiz)
  end

  # to be able to calculate total score for an assessment from another model
  def default_total_score
    problems.sum :max_score
  end

  def source_config_file_path
    Rails.root.join("courses", course.name, sanitized_name, "#{sanitized_name}.rb")
  end

  # name is already sanitized during the creation process
  def unique_source_config_file_path
    path "#{name}.rb"
  end

  def source_config_file_backup_path
    source_config_file_path.sub_ext(".rb.bak")
  end

  def date_to_s(date)
    date.strftime("%b %e at %l:%M%P")
  end

  def load_dir_to_tar(dir_path, asmt_dir, tar, filters = [], export_dir = "")
    Dir[File.join(dir_path, asmt_dir, "**")].each do |file|
      mode = File.stat(file).mode
      relative_path = file.sub(%r{^#{Regexp.escape dir_path}/?}, "")
      export_path = if export_dir == ""
                      relative_path
                    else
                      File.join(export_dir, relative_path)
                    end

      if File.directory?(file)
        if filters.all? { |filter|
          !Archive.in_dir?(Pathname.new(filter), Pathname.new(file), strict: false)
        }
          tar.mkdir export_path, mode
          load_dir_to_tar(dir_path, relative_path, tar, filters, export_dir)
        end
      else
        tar.add_file export_path, mode do |tarFile|
          File.open(file, "rb") { |f| tarFile.write f.read }
        end
      end
    end
  end

private

  def saved_change_to_grade_related_fields?
    saved_change_to_due_at? or saved_change_to_max_grace_days? or
      saved_change_to_version_threshold? or
      saved_change_to_late_penalty_id? or
      saved_change_to_version_penalty_id?
  end

  def saved_change_to_due_at_or_max_grace_days?
    saved_change_to_due_at? or saved_change_to_max_grace_days?
  end

  def path(filename)
    Rails.root.join("courses", course.name, name, filename)
  end

  def source_config_module_name
    sanitized_name.camelize
  end

  # rubocop:disable Style/ClassVars
  @@CONFIG_FILE_LAST_LOADED = {}
  # rubocop:enable Style/ClassVars

  def reload_config_file
    # remove the previously loaded config module
    Object.send :remove_const, config_module_name if Object.const_defined? config_module_name

    if Object.const_defined? unique_config_module_name
      Object.send :remove_const,
                  unique_config_module_name
    end

    # force load config file (see http://www.ruby-doc.org/core-2.0.0/Kernel.html#method-i-load)
    load unique_config_file_path

    # updated last loaded time
    @@CONFIG_FILE_LAST_LOADED[unique_config_file_path] = Time.current

    logger.info "Reloaded #{unique_config_file_path}"
  end

  def config_file_updated?
    # config file last modified time
    config_file_mtime = File.mtime unique_config_file_path

    # get last loaded time of config file by this process
    last_loaded_time = @@CONFIG_FILE_LAST_LOADED[unique_config_file_path]

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

  # Recursively sort a hash by its keys and return an array
  # Inspired by: https://bdunagan.com/2011/10/23/ruby-tip-sort-a-hash-recursively/
  def sort_hash(h)
    h.class[
      h.each do |k, v|
        if v.instance_of? Hash
          h[k] = sort_hash v
        elsif v.instance_of? Array
          h[k] = v.collect { |x| sort_hash x }
        end
        # else do nothing
      end.sort]
  end

  def serialize
    s = {}
    s["general"] = serialize_general
    s["problems"] = problems.map(&:serialize)
    s["autograder"] = autograder.serialize if has_autograder?
    s["scoreboard"] = scoreboard.serialize if has_scoreboard?
    s["late_penalty"] = late_penalty.serialize if late_penalty
    s["version_penalty"] = version_penalty.serialize if version_penalty
    # convert to string so if instructor wants to edit the date in yml
    # can do so easily
    s["dates"] = { start_at: start_at.to_s,
                   due_at: due_at.to_s,
                   end_at: end_at.to_s }.deep_stringify_keys
    s
  end

  GENERAL_SERIALIZABLE = Set.new %w[display_name category_name description handin_filename
                                    handin_directory max_grace_days handout
                                    writeup max_submissions disable_handins max_size
                                    version_threshold is_positive_grading embedded_quiz group_size
                                    github_submission_enabled allow_student_assign_group
                                    is_positive_grading disable_network]

  def serialize_general
    Utilities.serializable attributes, GENERAL_SERIALIZABLE
  end

  def deserialize(s)
    unless s["general"]
      raise "General section missing in yaml"
    end

    if s["dates"] && s["dates"]["start_at"]
      if s["dates"]["due_at"] && s["dates"]["end_at"]
        self.due_at = Time.zone.parse(s["dates"]["due_at"])
        self.start_at = Time.zone.parse(s["dates"]["start_at"])
        self.end_at = Time.zone.parse(s["dates"]["end_at"])
      else
        self.due_at = self.end_at = self.start_at = Time.zone.parse(s["dates"]["start_at"])
      end
    else
      self.due_at = self.end_at = self.start_at = Time.current + 1.day
    end

    self.quiz = false
    self.quizData = ""
    update!(s["general"])
    Problem.deserialize_list(self, s["problems"]) if s["problems"]

    if s["autograder"]
      autograder = Autograder.find_or_initialize_by(assessment_id: id)
      autograder.update(s["autograder"])
      self.autograder = autograder
    end
    if s["scoreboard"]
      scoreboard = Scoreboard.find_or_initialize_by(assessment_id: id)
      scoreboard.update(s["scoreboard"])
      self.scoreboard = scoreboard
    end
    if s["late_penalty"]
      late_penalty ||= Penalty.new
      late_penalty.update(s["late_penalty"])
      self.late_penalty = late_penalty
    end
    if s["version_penalty"]
      version_penalty ||= Penalty.new
      version_penalty.update(s["version_penalty"])
      self.version_penalty = version_penalty
    end
    # necessary for penaltu data to be saved properly
    save!
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
    File.file?(path(name))
  end

  def verify_dates_order
    errors.add :due_at, "must be after the start date" if start_at > due_at
    errors.add :end_at, "must be after the due date" if due_at > end_at
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

  def valid_handout
    return true if handout.blank? || handout_is_url? || handout_is_file?

    errors.add :handout, "must be a URL or a file in the assessment folder"
    false
  end

  def valid_writeup
    return true if writeup.blank? || writeup_is_url? || writeup_is_file?

    errors.add :writeup, "must be a URL or a file in the assessment folder"
    false
  end

  def valid_handin_directory
    return true if handin_directory.blank? || Archive.in_dir?(handin_directory_path, folder_path)

    errors.add :handin_directory, "must be a directory in the assessment folder"
    false
  end

  def invalidate_raw_scores
    # key-based invalidation (see submission.raw_score)
    # rubocop:disable Rails/SkipsModelValidations
    touch
    # rubocop:enable Rails/SkipsModelValidations
  end

  def sanitized_name
    name.gsub(/[.-]/, "")
  end

  def active?
    Time.current <= course.end_date
  end

  ##
  # This function attempts to preserve Backwards Compatibility for when assessments are
  # imported from a YAML file
  #
  GENERAL_BC = { "category" => "category_name",
                 "handout_filename" => "handout",
                 "writeup_filename" => "writeup",
                 "has_autograde" => nil,
                 "has_scoreboard" => nil,
                 "has_svn" => nil }.freeze
  BACKWARDS_COMPATIBILITY = { "autograding_setup" => "autograder",
                              "scoreboard_setup" => "scoreboard" }.freeze
  def backwards_compatibility(props)
    GENERAL_BC.each do |old, new|
      next unless props["general"].key?(old)

      props["general"][new] = props["general"][old] unless new.nil?
      props["general"].delete(old)
    end
    BACKWARDS_COMPATIBILITY.each do |old, new|
      next unless props.key?(old)

      props[new] = props[old]
      props.delete(old)
    end
    props["general"]["category_name"] ||= "General"
  end

  include AssessmentAssociationCache
end
