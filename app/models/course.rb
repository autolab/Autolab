require "association_cache"
require "fileutils"
require "etc"
require_relative "../services/unix_group_manager"
require_relative "../services/filesystem_enforcer"

class Course < ApplicationRecord
  trim_field :name, :semester, :display_name
  validates :name, uniqueness: { case_sensitive: false }
  validates :display_name, :start_date, :end_date, presence: true
  validates :late_slack, :grace_days, :late_penalty, :version_penalty, presence: true
  validates :grace_days, numericality: { greater_than_or_equal_to: 0 }
  validates :version_threshold, numericality: { only_integer: true, greater_than_or_equal_to: -1 }
  validate :order_of_dates
  validate :valid_name?, on: :create
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
  before_create :ensure_unix_group_exists
  after_create :init_course_folder

  # Constants
  VALID_CODE_REGEX = /\A[A-Z0-9]{6}\z/
  VALID_CODE_REGEX_HTML = "[a-zA-Z0-9]{6}".freeze

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

    newCourse.late_penalty = Penalty.new(kind: "points", value: "0")
    newCourse.version_penalty = Penalty.new(kind: "points", value: "0")

    unless newCourse.save
      raise "Failed to create course #{newCourse.name}: " \
            "#{newCourse.errors.full_messages.join(', ')}"
    end

    instructor = User.where(email: instructor_email).first
    if instructor.nil?
      begin
        instructor = User.instructor_create(instructor_email, newCourse.name)
      rescue StandardError => e
        newCourse.destroy
        raise "Failed to create instructor for course: #{e}"
      end
    end

    newCUD = newCourse.course_user_data.new
    newCUD.user = instructor
    newCUD.instructor = true
    unless newCUD.save
      newCourse.destroy
      raise "Failed to create CUD for instructor of new course #{newCourse.name}"
    end

    begin
      # Unix group was already created in before_create callback
      # IMPORTANT: Reload course config BEFORE fixing directory permissions
      # because reload_course_config needs to read course.rb, and fix_tree
      # sets directory to drwxrws--- which would block access
      newCourse.reload_course_config
      # Now that config is loaded, lock down directory permissions
      FilesystemEnforcer.fix_tree(newCourse.directory_path.to_s)
    rescue StandardError, SyntaxError
      newCUD.destroy
      newCourse.destroy
    end

    newCourse
  end

  # generate course folder
  def init_course_folder
    dir_path = directory_path
    group_name = UnixGroupManager.safe_group_name(name)

    # Ensure base dirs exist first
    FileUtils.mkdir_p dir_path
    FileUtils.mkdir_p Rails.root.join("assessmentConfig")
    FileUtils.mkdir_p Rails.root.join("courseConfig")
    
    # Log current ownership after creation
    begin
      stat = File.stat(dir_path)
      current_uid = stat.uid
      current_gid = stat.gid
      current_user = Etc.getpwuid(current_uid).name rescue "uid:#{current_uid}"
      current_group = Etc.getgrgid(current_gid).name rescue "gid:#{current_gid}"
      Rails.logger.info("Course directory #{dir_path} created with ownership: #{current_user}:#{current_group} (uid:#{current_uid}, gid:#{current_gid})")
    rescue StandardError => e
      Rails.logger.warn("Could not get current ownership of #{dir_path}: #{e.message}")
    end
    
    # Create initial files BEFORE setting strict ownership/permissions
    # This allows the Rails process to create files, then we fix ownership afterwards
    autolab_log_path = File.join(dir_path, "autolab.log")
    FileUtils.touch autolab_log_path
    course_rb_path = File.join(dir_path, "course.rb")
    default_course_rb = Rails.root.join("lib", "__defaultCourse.rb") # rubocop:disable Rails/FilePath
    FileUtils.cp default_course_rb, course_rb_path
    
    # Log file creation
    Rails.logger.info("Course files created: autolab.log=#{autolab_log_path}, course.rb=#{course_rb_path}")
    begin
      log_stat = File.stat(autolab_log_path) if File.exist?(autolab_log_path)
      rb_stat = File.stat(course_rb_path) if File.exist?(course_rb_path)
      Rails.logger.info("File ownership after creation - autolab.log: uid=#{log_stat.uid}, gid=#{log_stat.gid}, mode=#{log_stat.mode.to_s(8)}") if log_stat
      Rails.logger.info("File ownership after creation - course.rb: uid=#{rb_stat.uid}, gid=#{rb_stat.gid}, mode=#{rb_stat.mode.to_s(8)}") if rb_stat
    rescue StandardError => e
      Rails.logger.warn("Could not get file stats after creation: #{e.message}")
    end
    
    # Now set ownership on directory and files via delegate
    # When using delegate, get GID from delegate and use it directly
    if group_name
      if UnixGroupManager.delegate_enabled?
        # Always use delegate chgrp - runs on host with proper privileges
        # The Rails container doesn't have permission to chown, so delegate must do it
        Rails.logger.info("Setting group #{group_name} on #{dir_path} and files via delegate chgrp")
        
        # Give group creation a moment to complete
        sleep(0.2) if UnixGroupManager.ensure_group(group_name)
        
        # During course creation, we keep directory owned by Rails process temporarily
        # so it can read course.rb during reload_course_config. Ownership will be
        # changed to root:<course-group> after config loads (by FilesystemEnforcer.fix_tree)
        
        Rails.logger.info("Setting group ownership on directory and files via delegate (keeping Rails process as owner)")
        Rails.logger.info("Directory path: #{dir_path}, Group: #{group_name}")
        
        # Set group ownership on directory (keep current owner = Rails process)
        # This allows Rails to access the directory, but sets the group correctly
        chgrp_success = UnixGroupManager.chgrp_path(dir_path.to_s, group_name, owner: nil)
        Rails.logger.info("Directory chgrp result: #{chgrp_success ? 'success' : 'failed'}")
        
        if chgrp_success
          # Log current state before chmod
          begin
            stat_before_chmod = File.stat(dir_path)
            Rails.logger.info("Directory before chmod: uid=#{stat_before_chmod.uid}, gid=#{stat_before_chmod.gid}, mode=#{stat_before_chmod.mode.to_s(8)}")
          rescue StandardError => e
            Rails.logger.warn("Could not stat directory before chmod: #{e.message}")
          end
          
          # Set permissive directory permissions (drwxrwxr-x = 0775)
          # This ensures the Rails process can read files during reload_course_config
          chmod_success = UnixGroupManager.chmod_path(dir_path.to_s, 0o775)
          Rails.logger.info("Directory chmod result: #{chmod_success ? 'success' : 'failed'}")
          
          # Log state after chmod
          begin
            stat_after_chmod = File.stat(dir_path)
            Rails.logger.info("Directory after chmod: uid=#{stat_after_chmod.uid}, gid=#{stat_after_chmod.gid}, mode=#{stat_after_chmod.mode.to_s(8)}")
          rescue StandardError => e
            Rails.logger.warn("Could not stat directory after chmod: #{e.message}")
          end
          
          # Set group ownership on files (keep current owner = Rails process)
          # This allows Rails to read the files, but sets the group correctly
          if File.exist?(autolab_log_path)
            file_chgrp_success = UnixGroupManager.chgrp_path(autolab_log_path, group_name, owner: nil)
            Rails.logger.info("autolab.log chgrp result: #{file_chgrp_success ? 'success' : 'failed'}")
            begin
              log_stat = File.stat(autolab_log_path)
              Rails.logger.info("autolab.log after chgrp: uid=#{log_stat.uid}, gid=#{log_stat.gid}, mode=#{log_stat.mode.to_s(8)}")
            rescue StandardError => e
              Rails.logger.warn("Could not stat autolab.log: #{e.message}")
            end
          end
          
          if File.exist?(course_rb_path)
            file_chgrp_success = UnixGroupManager.chgrp_path(course_rb_path, group_name, owner: nil)
            Rails.logger.info("course.rb chgrp result: #{file_chgrp_success ? 'success' : 'failed'}")
            begin
              rb_stat = File.stat(course_rb_path)
              Rails.logger.info("course.rb after chgrp: uid=#{rb_stat.uid}, gid=#{rb_stat.gid}, mode=#{rb_stat.mode.to_s(8)}")
              
              # Test if file is readable
              if File.readable?(course_rb_path)
                Rails.logger.info("course.rb is readable by current process")
              else
                Rails.logger.warn("course.rb is NOT readable by current process - this will cause reload_config_file to fail!")
              end
            rescue StandardError => e
              Rails.logger.warn("Could not stat course.rb: #{e.message}")
            end
          else
            Rails.logger.error("course.rb does not exist at #{course_rb_path}")
          end
          
          # Verify directory group ownership worked
          begin
            stat_after = File.stat(dir_path)
            gid = UnixGroupManager.get_group_gid(group_name)
            if gid && stat_after.gid == gid
              Rails.logger.info("Successfully set group #{group_name} (gid #{gid}) on course directory #{dir_path} via delegate (owner remains Rails process for now)")
            else
              Rails.logger.warn("Group ownership mismatch - expected gid #{gid}, got #{stat_after.gid}")
            end
            
            # Test if directory is accessible
            if File.readable?(dir_path) && File.executable?(dir_path)
              Rails.logger.info("Directory is readable and executable by current process")
            else
              Rails.logger.warn("Directory is NOT readable/executable by current process - this will cause reload_config_file to fail!")
            end
          rescue StandardError => e
            Rails.logger.warn("Could not verify group ownership: #{e.message}")
          end
        else
          Rails.logger.error("Failed to set group #{group_name} via delegate chgrp. Ensure UnixOps daemon is running and accessible.")
        end
      else
        # Not using delegate - look up locally (only works if groups exist in container)
        begin
          group_info = Etc.getgrnam(group_name)
          gid = group_info.gid
          File.chown(nil, gid, dir_path.to_s)
          # Set permissive directory permissions temporarily (drwxrwxr-x = 0775)
          File.chmod(0o775, dir_path.to_s)
          File.chown(nil, gid, autolab_log_path) if File.exist?(autolab_log_path)
          File.chown(nil, gid, course_rb_path) if File.exist?(course_rb_path)
          Rails.logger.info("Successfully set group #{group_name} (gid #{gid}) on course directory #{dir_path}")
        rescue ArgumentError => e
          Rails.logger.error("Group #{group_name} not found locally. Delegate is not enabled, so local lookup is required.")
        end
      end
    end
    
    # Set directory group ownership but keep permissions permissive temporarily
    # This allows the Rails process to read course.rb during reload_course_config
    # Strict permissions will be set later by FilesystemEnforcer.fix_tree (called from controller)
    
    # Set file permissions to ensure files are readable/writable by owner
    # Files are set to -rw-rw---- which allows owner (Rails process) and group to read/write
    Rails.logger.info("Applying FilesystemEnforcer to files to ensure correct permissions")
    if File.exist?(autolab_log_path)
      Rails.logger.info("Fixing permissions on autolab.log")
      FilesystemEnforcer.fix_path(autolab_log_path, group_name: group_name)
      begin
        log_stat = File.stat(autolab_log_path)
        Rails.logger.info("autolab.log after FilesystemEnforcer: uid=#{log_stat.uid}, gid=#{log_stat.gid}, mode=#{log_stat.mode.to_s(8)}")
      rescue StandardError => e
        Rails.logger.warn("Could not stat autolab.log after FilesystemEnforcer: #{e.message}")
      end
    end
    if File.exist?(course_rb_path)
      Rails.logger.info("Fixing permissions on course.rb")
      FilesystemEnforcer.fix_path(course_rb_path, group_name: group_name)
      begin
        rb_stat = File.stat(course_rb_path)
        Rails.logger.info("course.rb after FilesystemEnforcer: uid=#{rb_stat.uid}, gid=#{rb_stat.gid}, mode=#{rb_stat.mode.to_s(8)}")
        Rails.logger.info("course.rb readable? #{File.readable?(course_rb_path)}, executable? #{File.executable?(course_rb_path)}")
      rescue StandardError => e
        Rails.logger.warn("Could not stat course.rb after FilesystemEnforcer: #{e.message}")
      end
    else
      Rails.logger.error("course.rb does not exist when trying to apply FilesystemEnforcer!")
    end
    
    # Note: We intentionally do NOT set strict directory permissions (drwxrws---) here
    # because the Rails process needs to access the directory to read course.rb during reload_course_config
    # The directory permissions will be properly locked down by FilesystemEnforcer.fix_tree
    # which is called from courses_controller after reload_course_config succeeds
    
    # Ensure courseConfig and assessmentConfig directories exist and are accessible
    # These are shared directories, so they should be writable by the Rails process
    # We only fix ownership/group, not strict permissions (they should remain writable)
    course_config_dir = Rails.root.join("courseConfig").to_s
    assessment_config_dir = Rails.root.join("assessmentConfig").to_s
    
    # Just ensure they exist - don't lock them down (Rails needs to write config files)
    FileUtils.mkdir_p(course_config_dir) unless Dir.exist?(course_config_dir)
    FileUtils.mkdir_p(assessment_config_dir) unless Dir.exist?(assessment_config_dir)
    
    # Only fix ownership/group if using delegate (to ensure proper group ownership)
    # But don't use FilesystemEnforcer.fix_path which sets strict permissions
    if UnixGroupManager.delegate_enabled? && group_name
      autolab_group = ENV.fetch("COURSE_FS_GROUP", "autolab")
      # Set group ownership to autolab group (shared directory), keep permissive permissions
      UnixGroupManager.chgrp_path(course_config_dir, autolab_group, owner: nil) if Dir.exist?(course_config_dir)
      UnixGroupManager.chgrp_path(assessment_config_dir, autolab_group, owner: nil) if Dir.exist?(assessment_config_dir)
    end
  end

  def order_of_dates
    return if start_date.nil? || end_date.nil?

    errors.add(:start_date, "must come before end date") if start_date > end_date
  end

  def valid_name?
    if /\A(\w|-)+\z/.match?(name)
      true
    else
      suggest_name = name.gsub(/(\s+)/, "-").gsub(/([^\w-]+)/, "")
      name_error =
        if !suggest_name.empty?
          "cannot include characters other than alphanumeric characters, hyphens, " \
          "and underscores. Suggestion: #{suggest_name}"
        else
          "cannot include characters other than alphanumeric characters, hyphens, and underscores."
        end
      errors.add("name", name_error)
      false
    end
  end

  def valid_website?
    return true if website.nil? || website.eql?("")
    return true if website[0..7].eql?("https://")

    errors.add("website", "needs to start with https://")
    false
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
    disabled? || (disable_on_end? && DateTime.now > end_date)
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
    Rails.logger.info("=== Starting reload_config_file for course: #{name} ===")
    Rails.logger.info("Source config path: #{source_config_file_path}")
    Rails.logger.info("Config file path: #{config_file_path}")
    Rails.logger.info("Current process: uid=#{Process.uid}, gid=#{Process.gid}, euid=#{Process.euid}, egid=#{Process.egid}")
    
    # Verify source config file exists and is readable
    unless File.exist?(source_config_file_path)
      error_msg = "Source config file does not exist: #{source_config_file_path}"
      Rails.logger.error(error_msg)
      raise error_msg
    end
    
    # Check file permissions
    begin
      stat = File.stat(source_config_file_path)
      Rails.logger.info("Source file stats: uid=#{stat.uid}, gid=#{stat.gid}, mode=#{stat.mode.to_s(8)}")
      Rails.logger.info("Source file readable? #{File.readable?(source_config_file_path)}")
      Rails.logger.info("Source file executable? #{File.executable?(source_config_file_path)}")
      
      # Check directory permissions
      dir_stat = File.stat(File.dirname(source_config_file_path))
      Rails.logger.info("Source directory stats: uid=#{dir_stat.uid}, gid=#{dir_stat.gid}, mode=#{dir_stat.mode.to_s(8)}")
      Rails.logger.info("Source directory readable? #{File.readable?(File.dirname(source_config_file_path))}")
      Rails.logger.info("Source directory executable? #{File.executable?(File.dirname(source_config_file_path))}")
    rescue StandardError => e
      Rails.logger.warn("Could not stat source config file or directory: #{e.message}")
    end
    
    # Read source config file
    Rails.logger.info("Attempting to open and read source config file...")
    begin
      s = File.open(source_config_file_path, "r")
      lines = s.readlines
      s.close
      Rails.logger.info("Successfully read #{lines.length} lines from source config file")
    rescue Errno::EACCES => e
      error_msg = "Permission denied reading #{source_config_file_path}: #{e.message}. Check file permissions and directory permissions."
      Rails.logger.error(error_msg)
      Rails.logger.error("File stats: #{File.stat(source_config_file_path).inspect rescue 'could not stat'}")
      raise error_msg
    rescue StandardError => e
      error_msg = "Error reading #{source_config_file_path}: #{e.message}"
      Rails.logger.error(error_msg)
      Rails.logger.error("Exception class: #{e.class}")
      raise error_msg
    end

    Rails.logger.info("Compiling config source...")
    config_source = File.open(source_config_file_path, "r", &:read)
    RubyVM::InstructionSequence.compile(config_source)
    Rails.logger.info("Config source compiled successfully")

    # Ensure courseConfig directory exists and is writable
    config_dir = File.dirname(config_file_path)
    Rails.logger.info("Ensuring courseConfig directory exists: #{config_dir}")
    FileUtils.mkdir_p(config_dir) unless Dir.exist?(config_dir)
    
    begin
      config_dir_stat = File.stat(config_dir) if Dir.exist?(config_dir)
      Rails.logger.info("courseConfig directory stats: uid=#{config_dir_stat.uid}, gid=#{config_dir_stat.gid}, mode=#{config_dir_stat.mode.to_s(8)}") if config_dir_stat
      Rails.logger.info("courseConfig directory writable? #{File.writable?(config_dir)}")
    rescue StandardError => e
      Rails.logger.warn("Could not stat courseConfig directory: #{e.message}")
    end
    
    if File.exist? config_file_path
      Rails.logger.info("Backing up existing config file...")
      File.rename(config_file_path, config_backup_file_path)
      FilesystemEnforcer.fix_path(config_backup_file_path.to_s)
    end

    # Write processed config file
    Rails.logger.info("Writing processed config file to #{config_file_path}...")
    begin
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
      Rails.logger.info("Successfully wrote processed config file")
    rescue Errno::EACCES => e
      error_msg = "Permission denied writing to #{config_file_path}: #{e.message}. Check courseConfig directory permissions."
      Rails.logger.error(error_msg)
      raise error_msg
    rescue StandardError => e
      error_msg = "Error writing to #{config_file_path}: #{e.message}"
      Rails.logger.error(error_msg)
      raise error_msg
    end
    
    Rails.logger.info("Applying FilesystemEnforcer to config file...")
    FilesystemEnforcer.fix_path(config_file_path.to_s)

    Rails.logger.info("Loading config file...")
    load(config_file_path)
    Rails.logger.info("Evaluating config module: #{config_module_name}")
    # rubocop:disable Security/Eval
    eval(config_module_name)
    # rubocop:enable Security/Eval
    Rails.logger.info("=== Successfully completed reload_config_file for course: #{name} ===")
  end

  # Reload the course config file and extend the loaded methods to AdminsController
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
    invalidate_cgdubs
    # rubocop:disable Rails/SkipsModelValidations
    assessments.update_all(updated_at: Time.current)
    # rubocop:enable Rails/SkipsModelValidations
  end

  def config
    @config ||= config!
  end

  def students
    course_user_data.where(course_assistant: false, instructor: false, dropped: [false, nil])
  end

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
    asmts.reject { |asmt| asmt.due_at > date }
  end

  def get_autocomplete_data
    users = {}
    usersEncoded = {}
    course_user_data.each do |cud|
      users[CGI.escapeHTML cud.full_name_with_email] = cud.id
      usersEncoded[Base64.strict_encode64(cud.full_name_with_email.strip).strip] = cud.id
    end
    [users, usersEncoded]
  end

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
        tar.mkdir course_dir, File.stat(File.join(base_path)).mode

        # save course.rb
        source_file = File.open(File.join(base_path, rb_path), "rb")
        tar.add_file File.join(course_dir, rb_path), File.stat(source_file).mode do |tar_file|
          tar_file.write(source_file.read)
        end
        source_file.close

        # save course and metrics config
        tar.add_file File.join(course_dir, config_path), mode do |tar_file|
          tar_file.write(dump_yaml(export_configs&.include?("metrics_config")))
        end

        # save assessments
        if export_configs&.include?("assessments")
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
    saved_change_to_late_slack? || saved_change_to_grace_days? ||
      saved_change_to_version_threshold? || saved_change_to_late_penalty_id? ||
      saved_change_to_version_penalty_id?
  end

  def grace_days_or_late_slack_changed?
    grace_days_changed? || late_slack_changed?
  end

  def saved_change_to_grace_days_or_late_slack?
    saved_change_to_grace_days? || saved_change_to_late_slack?
  end

  def cgdub_dependencies_updated
    self.cgdub_dependencies_updated_at = Time.current
  end

  # Ensure Unix group exists before course is created
  # This allows init_course_folder to set correct permissions
  def ensure_unix_group_exists
    group_name = UnixGroupManager.safe_group_name(name)
    return unless group_name
    
    # Ensure group is created via delegate (UnixOps daemon)
    # When using delegate, we trust the delegate - no local verification needed
    success = UnixGroupManager.ensure_group(group_name)
    
    if success
      Rails.logger.info("Unix group #{group_name} creation delegated for course #{name}")
    else
      Rails.logger.error("Failed to create Unix group #{group_name} via delegate for course #{name}")
      Rails.logger.error("Check that UnixOps daemon is running and accessible at #{ENV['UNIX_OPS_DELEGATE_URL']}")
    end
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
        s["watchlist_configuration"] = watchlist_configuration.serialize
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
