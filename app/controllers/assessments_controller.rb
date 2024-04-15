require "archive"
require "csv"
require "fileutils"
require "rubygems/package"
require "statistics"
require "yaml"
require "utilities"

class AssessmentsController < ApplicationController
  include ActiveSupport::Callbacks
  include AssessmentAutogradeCore

  autolab_require Rails.root.join("app/controllers/assessment/handin.rb")
  include AssessmentHandin

  autolab_require Rails.root.join("app/controllers/assessment/handout.rb")
  include AssessmentHandout

  autolab_require Rails.root.join("app/controllers/assessment/grading.rb")
  include AssessmentGrading

  autolab_require Rails.root.join("app/controllers/assessment/autograde.rb")
  include AssessmentAutograde

  # this is inherited from ApplicationController
  before_action :set_assessment, except: %i[index new create install_assessment
                                            import_asmt_from_tar import_assessment
                                            log_submit local_submit autograde_done
                                            import_assessments course_onboard_install_asmt]
  skip_before_action :set_breadcrumbs, only: %i[index]
  before_action :set_assessment_breadcrumb, except: %i[index show install_assessment]
  before_action :set_manage_course_breadcrumb, only: %i[install_assessment new]
  before_action :set_install_asmt_breadcrumb, only: %i[new]
  before_action :set_submission, only: [:viewFeedback]

  # We have to do this here, because the modules don't inherit ApplicationController.

  # Grading
  action_auth_level :bulkGrade, :course_assistant
  action_auth_level :quickSetScore, :course_assistant
  action_auth_level :quickSetScoreDetails, :course_assistant
  action_auth_level :submission_popover, :course_assistant
  action_auth_level :score_grader_info, :course_assistant
  action_auth_level :viewGradesheet, :course_assistant
  action_auth_level :quickGetTotal, :course_assistant
  action_auth_level :statistics, :instructor

  # Handin
  action_auth_level :handin, :student

  # Handout
  action_auth_level :handout, :student

  # Autograde
  action_no_auth :autograde_done
  action_auth_level :regrade, :instructor
  action_auth_level :regradeAll, :instructor
  action_no_auth :log_submit
  action_no_auth :local_submit

  IMPORT_ASMT_FAILURE_STATUS = "FAIL".freeze
  IMPORT_ASMT_SUCCESS_STATUS = "SUCCESS".freeze
  DISALLOWED_LIST_OPTIONS = %w[edit reload viewGradesheet].freeze

  def index
    @is_instructor = @cud.has_auth_level? :instructor
    announcements_tmp = Announcement.where("start_date < :now AND end_date > :now",
                                           now: Time.current)
                                    .where(persistent: false)
    @announcements = announcements_tmp.where(course_id: @course.id)
                                      .or(announcements_tmp.where(system: true)).order(:start_date)
    # Only display course attachments on course landing page
    @course_attachments = if @cud.instructor?
                            @course.attachments.where(assessment_id: nil).ordered
                          else
                            @course.attachments.where(assessment_id: nil).released.ordered
                          end
  end

  # GET /assessments/new
  # Installs a new assessment, either by
  # creating it from scratch, or importing it from an existing
  # assessment directory.
  action_auth_level :new, :instructor

  def new
    @assessment = @course.assessments.new
    return if GithubIntegration.connected

    @assessment.github_submission_enabled = false
  end

  # install_assessment - Installs a new assessment, either by
  # creating it from scratch, or importing it from an existing
  # assessment directory on file system, or from an uploaded
  # tar file with the assessment directory.
  action_auth_level :install_assessment, :instructor
  def install_assessment
    get_unimported_asmts_from_dir
  end

  action_auth_level :course_onboard_install_asmt, :instructor
  def course_onboard_install_asmt
    get_unimported_asmts_from_dir
  end

  action_auth_level :import_asmt_from_tar, :instructor

  def import_asmt_from_tar
    tarFile = params["tarFile"]
    if tarFile.nil?
      flash[:error] = "Please select an assessment tarball for uploading."
      redirect_to(action: "install_assessment")
      return
    end

    begin
      tarFile = File.new(tarFile.open, "rb")
      tar_extract = Gem::Package::TarReader.new(tarFile)
      tar_extract.rewind
      is_valid_tar, asmt_name = valid_asmt_tar(tar_extract)
      tar_extract.close
      unless is_valid_tar
        flash[:error] +=
          "<br>Invalid tarball. A valid assessment tar has a single root "\
          "directory that's named after the assessment, containing an "\
          "assessment yaml file"
        flash[:html_safe] = true
        redirect_to(action: "install_assessment") && return
      end
    rescue SyntaxError => e
      flash[:error] = "Error parsing assessment configuration file:"
      # escape so that <compiled> doesn't get treated as a html tag
      flash[:error] += "<br><pre>#{CGI.escapeHTML e.to_s}</pre>"
      flash[:html_safe] = true
      redirect_to(action: "install_assessment") && return
    rescue StandardError => e
      flash[:error] = "Error while reading the tarball -- #{e.message}."
      redirect_to(action: "install_assessment") && return
    end

    # Check if the assessment already exists.
    existing_asmt = @course.assessments.find_by(name: asmt_name)

    # If all requirements are satisfied, extract assessment files.
    begin
      dir_path = @course.directory_path
      assessment_path = Rails.root.join("courses", @course.name, asmt_name)
      tar_extract.rewind
      tar_extract.each do |entry|
        relative_pathname = entry.full_name
        entry_file = File.join(dir_path, relative_pathname)

        # Ensure file will lie within course, otherwise skip
        # Allow equality for the main directory to be created
        next unless Archive.in_dir?(Pathname(entry_file), Pathname(assessment_path), strict: false)
        next if existing_asmt && Archive.in_dir?(Pathname(entry_file),
                                                 existing_asmt.handin_directory_path, strict: false)

        if entry.directory?
          FileUtils.mkdir_p(entry_file,
                            mode: entry.header.mode, verbose: false)
          # In case the directory was implicitly created by a file
          FileUtils.chmod entry.header.mode, entry_file,
                          verbose: false
        elsif entry.file?
          # Skip config files
          next if existing_asmt && (entry_file == existing_asmt.asmt_yaml_path.to_s ||
            entry_file == existing_asmt.unique_source_config_file_path.to_s ||
            entry_file == existing_asmt.log_path.to_s)

          # Default to 0755 so that directory is writeable, mode will be updated later
          FileUtils.mkdir_p(File.dirname(entry_file),
                            mode: 0o755, verbose: false)
          File.open(entry_file, "wb") do |f|
            f.write entry.read
          end
          FileUtils.chmod entry.header.mode, entry_file,
                          verbose: false
        elsif entry.header.typeflag == "2"
          File.symlink entry.header.linkname, entry_file
        end
      end
      tar_extract.close
    rescue StandardError => e
      flash[:error] = "Error while extracting tarball to server -- #{e.message}."
      redirect_to(action: "install_assessment") && return
    end

    if existing_asmt
      flash[:success] = "IMPORTANT: Successfully uploaded files for existing assessment
                         #{asmt_name}. The YAML and config file were NOT reuploaded.
                         If you would like to edit these fields, do so via 'Edit assessment'."
      @assessment = @course.assessments.find_by(name: asmt_name)
      redirect_to(course_assessment_path(@course, @assessment)) && return
    end

    # asmt files now in file system, so finish import via file system
    import_result = importAssessmentsFromFileSystem([asmt_name], true)
    handleImportResults(import_result, asmt_name)
  end

  # import_assessments - Allows for multiple simultaneous imports of asmts
  # from file system, returning results of each import
  action_auth_level :import_assessments, :instructor
  def import_assessments
    if params[:assessment_names].nil? || !params[:assessment_names].is_a?(Array)
      render json: { error: "Did not receive array of assessment names" }, status: :bad_request
      return
    end
    import_results = importAssessmentsFromFileSystem(params[:assessment_names], false)
    import_results = import_results.each(&:to_json)
    render json: import_results
  end

  # import_assessment - Imports an existing assessment from local file system
  action_auth_level :import_assessment, :instructor

  def import_assessment
    if params[:assessment_name].blank?
      flash[:error] = "No assessment name specified."
      redirect_to(install_assessment_course_assessments_path(@course))
    end

    if params[:overwrite]
      flash[:success] = "IMPORTANT: Successfully uploaded files for existing assessment
                         #{params[:assessment_name]}. The YAML and config file were NOT reuploaded.
                         If you would like to edit these fields, do so via 'Edit assessment'."
      @assessment = @course.assessments.find_by(name: params[:assessment_name])
      redirect_to(course_assessment_path(@course, @assessment)) && return
    end

    cleanup_on_failure = params[:cleanup_on_failure]
    @assessment = @course.assessments.new(name: params[:assessment_name])
    assessment_path = Rails.root.join("courses/#{@course.name}/#{@assessment.name}")
    # not sure if this check is 100% necessary anymore, but is a last resort
    # against creating an invalid assessment
    if params[:assessment_name] != @assessment.name
      flash[:error] = "Error creating assessment: Config module is named #{@assessment.name}
                       but assessment file name is #{params[:assessment_name]}"
      # destroy model
      destroy_no_redirect
      # delete files explicitly b/c the paths don't match ONLY if
      # import was from tarball
      FileUtils.rm_rf(assessment_path) if cleanup_on_failure
      redirect_to(install_assessment_course_assessments_path(@course)) && return
    end
    import_result = importAssessmentsFromFileSystem([params[:assessment_name]], true)
    handleImportResults(import_result, params[:assessment_name])
  end

  # helper function that finalizes importing assessments, using files in file system
  # called by both import_asmt_from_tar and importAssessment
  # can import multiple assessments at once, returning statuses of import and any errors
  def importAssessmentsFromFileSystem(assessment_names, cleanup_on_failure)
    import_statuses = Array.new(assessment_names.length)
    import_statuses = import_statuses.map do |_status|
      {
        status: AssessmentsController::IMPORT_ASMT_SUCCESS_STATUS,
        errors: "",
        messages: []
      }
    end
    assessment_names.each_with_index do |assessment_name, i|
      new_assessment = @course.assessments.new(name: assessment_name)
      assessment_path = Rails.root.join("courses/#{@course.name}/#{new_assessment.name}")
      # not sure if this check is 100% necessary anymore, but is a last resort
      # against creating an invalid assessment
      if assessment_name != new_assessment.name
        import_statuses[i][:errors] = "Error creating assessment: Config module is
            named #{new_assessment.name} but assessment file name is #{assessment_name}"
        import_statuses[i][:status] = AssessmentsController::IMPORT_ASMT_FAILURE_STATUS
        # destroy model
        destroy_no_redirect(new_assessment)
        # delete files explicitly b/c the paths don't match ONLY if
        # import was from tarball
        FileUtils.rm_rf(assessment_path) if cleanup_on_failure
        next
      end

      begin
        new_assessment.load_yaml # this will save the assessment
      rescue StandardError => e
        import_statuses[i][:errors] = "Error loading yaml: #{e}"
        import_statuses[i][:status] = AssessmentsController::IMPORT_ASMT_FAILURE_STATUS
        destroy_no_redirect(new_assessment)
        # delete files explicitly b/c the paths don't match ONLY if
        # import was from tarball
        FileUtils.rm_rf(assessment_path) if cleanup_on_failure
        next
      end
      new_assessment.load_embedded_quiz # this will check and load embedded quiz
      constructed_config_file = new_assessment.construct_folder # make sure there's a handin folder
      if constructed_config_file
        import_statuses[i][:messages].append(
          "Could not find config file, constructed default config file."
        )
      end
      begin
        new_assessment.load_config_file # only call this on saved assessments
      rescue StandardError => e
        import_statuses[i][:errors] = "Error loading config module: #{e}"
        import_statuses[i][:status] = AssessmentsController::IMPORT_ASMT_FAILURE_STATUS
        destroy_no_redirect(new_assessment)
        # delete files explicitly b/c the paths don't match ONLY if
        # import was from tarball
        FileUtils.rm_rf(assessment_path) if cleanup_on_failure
        next
      end
    end
    import_statuses
  end

  # helper function to take importAssessments results and show flashes / error messages
  # currently only supports 1 import result (since used by legacy import functions)
  def handleImportResults(import_result, asmt_name)
    return unless import_result.length == 1

    import_result = import_result[0]
    if import_result[:status] == AssessmentsController::IMPORT_ASMT_SUCCESS_STATUS
      @assessment = @course.assessments.find_by!(name: asmt_name)
      flash[:success] = "Successfully imported #{asmt_name}."
      unless import_result[:messages].empty?
        flash[:html_safe] = true
        flash[:notice] = import_result[:messages].join("<br>")
      end
      redirect_to(course_assessment_path(@course, @assessment))
    else
      flash[:error] = import_result[:errors]
      redirect_to(install_assessment_course_assessments_path(@course))
    end
  end

  # create - Creates an assessment from an assessment directory
  # residing in the course directory.
  action_auth_level :create, :instructor

  def create
    @assessment = @course.assessments.new(new_assessment_params)
    if @assessment.name.blank?
      # Validate the name, very similar to valid Ruby identifiers, but also allowing hyphens
      # We just want to prevent file traversal attacks here, and stop names that break routing
      # first regex - try to sanitize input, allow special characters in display name but not name
      # if the sanitized doesn't match the required identifier structure, then we reject
      begin
        # Attempt name generation, try to match to a substring that is valid within the
        # display name.
        # UB Update Feb 13, 2024: Automatically replace invalid unique name characters with dashes
        # instead of only taking the characters up to the first invalid character.
        display_name_dashed = @assessment.display_name.gsub(/[^a-zA-Z0-9-]/, "-")
        while display_name_dashed.include?("--")
          # Remove double dashes
          display_name_dashed = display_name_dashed.gsub("--", "-")
        end
        display_name_dashed = display_name_dashed.delete_prefix("-")
        display_name_dashed = display_name_dashed.delete_suffix("-")
        match = display_name_dashed.match(Assessment::VALID_NAME_SANITIZER_REGEX)
        unless match.nil?
          sanitized_display_name = match.captures[0]
        end

        if sanitized_display_name !~ Assessment::VALID_NAME_REGEX
          flash[:error] =
            "Assessment name is blank or contains disallowed characters. Find more information on "\
            "valid assessment names "\
            '<a href="https://docs.autolabproject.com/lab/#assessment-naming-rules">here</a>'
          flash[:html_safe] = true
          redirect_to(action: :install_assessment)
          return
        end
      rescue StandardError
        flash[:error] =
          "Error creating name from display name. Find more information on "\
          "valid assessment names "\
          '<a href="https://docs.autolabproject.com/lab/#assessment-naming-rules">here</a>'
        flash[:html_safe] = true
        redirect_to(action: :install_assessment)
        return
      end

      # Update name in object
      @assessment.name = sanitized_display_name
    end

    # fill in other fields
    @assessment.course = @course
    @assessment.handin_directory = "handin"

    @assessment.handin_filename = if @assessment.github_submission_enabled
                                    "handin.tgz"
                                  else
                                    "handin.c"
                                  end

    @assessment.start_at = Time.current + 1.day
    @assessment.due_at = Time.current + 1.day
    @assessment.end_at = Time.current + 1.day
    @assessment.quiz = false
    @assessment.quizData = ""
    @assessment.max_submissions = params.include?(:max_submissions) ? params[:max_submissions] : -1

    begin
      @assessment.construct_folder
    rescue StandardError => e
      # Something bad happened. Undo everything
      flash[:error] = e.to_s
      begin
        FileUtils.remove_dir(@assessment.folder_path)
      rescue StandardError => e2
        flash[:error] += "An error occurred (#{e2}} " \
          " while recovering from a previous error (#{flash[:error]})"
        redirect_to(action: :install_assessment)
        return
      end
    end

    # From here on, if something weird happens, we rollback
    begin
      @assessment.save!
    rescue StandardError => e
      flash[:error] = "Error saving #{@assessment.name}: #{e}"
      redirect_to(action: :install_assessment)
      return
    end

    # reload the assessment's config file
    @assessment.load_config_file # only call this on saved assessments

    flash[:success] = "Successfully installed #{@assessment.name}."
    # reload the course config file
    begin
      @course.reload_course_config
    rescue StandardError, SyntaxError => e
      @error = e
      render("reload") && return
    end

    redirect_to([@course, @assessment]) && return
  end

  # raw_score
  # @param map of problem names to problem scores
  # @return score on this assignment not including any tweak or late penalty.
  # We generically cast all values to floating point numbers because we don't
  # trust the upstream developer to do that for us.
  def raw_score(scores)
    if @assessment.has_autograder? &&
       @assessment.overwrites_method?(:raw_score)
      sum = @assessment.config_module.raw_score(scores)
    else
      sum = 0.0
      scores.each_value { |value| sum += value.to_f }
    end

    sum
  end

  def grade
    @problem = @assessment.problems.find(params[:problem])
    @submission = @assessment.submissions.find(params[:submission])
    # Shows a form which has the submission on top, and feedback on bottom
    begin
      subFile = Rails.root.join("courses", @course.name, @assessment.name,
                                @assessment.handin_directory,
                                @submission.filename)
      @submissionData = File.read(subFile)
    rescue StandardError
      flash[:error] = "Could not read #{subFile}"
    end
    @score = @submission.scores.where(problem_id: @problem.id).first
  end

  def getAssessmentVariable(key)
    @assessmentVariables&.key(key)
  end

  # export - export an assessment by saving its persistent
  # properties in a yaml properties file.
  action_auth_level :export, :instructor

  def export
    dir_path = @course.directory_path.to_s
    asmt_dir = @assessment.name
    begin
      # Update the assessment config YAML file.
      @assessment.dump_yaml
      # Save embedded_quiz
      @assessment.dump_embedded_quiz
      # Pack assessment directory into a tarball.
      tarStream = StringIO.new("")
      Gem::Package::TarWriter.new(tarStream) do |tar|
        tar.mkdir asmt_dir, File.stat(File.join(dir_path, asmt_dir)).mode
        filter = [@assessment.handin_directory_path]
        @assessment.load_dir_to_tar(dir_path, asmt_dir, tar, filter)
      end
      tarStream.rewind
      tarStream.close
      send_data tarStream.string.force_encoding("binary"),
                filename: "#{@assessment.name}_#{Time.current.strftime('%Y%m%d')}.tar",
                content_type: "application/x-tar"
    rescue SystemCallError => e
      flash[:error] = "Unable to update the config YAML file: #{e}"
      redirect_to action: "index"
    rescue StandardError => e
      flash[:error] = "Unable to generate tarball -- #{e.message}"
      redirect_to action: "index"
    end
  end

  action_auth_level :destroy, :instructor

  def destroy
    @assessment.submissions.each(&:destroy)

    @assessment.attachments.each(&:destroy)

    # Delete config file copy in assessmentConfig
    if File.exist? @assessment.config_file_path
      File.delete @assessment.config_file_path
    end
    if File.exist? @assessment.config_backup_file_path
      File.delete @assessment.config_backup_file_path
    end
    if File.exist? @assessment.unique_config_file_path
      File.delete @assessment.unique_config_file_path
    end
    if File.exist? @assessment.unique_config_backup_file_path
      File.delete @assessment.unique_config_backup_file_path
    end

    name = @assessment.display_name
    @assessment.destroy # awwww!!!!
    flash[:success] = "The assessment #{name} has been deleted."
    redirect_to(course_path(@course)) && return
  end

  action_auth_level :show, :student

  def show
    set_handin
    begin
      extend_config_module(@assessment, @submission, @cud)
    rescue StandardError => e
      if @cud.has_auth_level? :instructor
        flash[:error] = "Error loading the config file: "
        flash[:error] += e.message
        flash[:error] += "<br/> Try reloading the course config file," \
      " or re-upload the course config file in order to recover your assessment."
        flash[:html_safe] = true
        redirect_to(edit_course_assessment_path(@course, @assessment)) && return
      else
        flash[:error] = "Error loading #{@assessment.display_name}. Please contact your instructor."
        redirect_to(course_path(@course)) && return
      end
    end

    @aud = @assessment.aud_for @cud.id

    # These are the default items displayed
    @list = {
      "history" => nil,
      "writeup" => nil,
      "handout" => nil,
      "groups" => nil,
      "scoreboard" => nil
    }

    if @assessment.overwrites_method?(:listOptions)
      list = @list
      @list = @assessment.config_module.listOptions(list)
    end

    # Explicitly disallow certain options that should not be displayed to students
    # This list is not exhaustive, but students wouldn't be able to view other links anyway
    @list.except!(*DISALLOWED_LIST_OPTIONS)

    # Remember the student ID in case the user wants visit the gradesheet
    session["gradeUser#{@assessment.id}"] = params[:cud_id] if params[:cud_id]

    @startTime = Time.current
    @effectiveCud = if @cud.instructor? && params[:cud_id]
                      @course.course_user_data.find(params[:cud_id])
                    else
                      @cud
                    end
    @attachments = if @cud.instructor?
                     @assessment.attachments.ordered
                   else
                     @assessment.attachments.released.ordered
                   end
    @submissions = @assessment.submissions.where(course_user_datum_id: @effectiveCud.id)
                              .order("version DESC")
    @extension = @assessment.extensions.find_by(course_user_datum_id: @effectiveCud.id)
    @problems = @assessment.problems

    results = @submissions.select("submissions.id AS submission_id",
                                  "problems.id AS problem_id",
                                  "scores.id AS score_id",
                                  "scores.*")
                          .joins("LEFT JOIN problems ON
        submissions.assessment_id = problems.assessment_id")
                          .joins("LEFT JOIN scores ON
        (submissions.id = scores.submission_id
        AND problems.id = scores.problem_id)")

    # Process them to get into a format we want.
    @scores = {}
    results.each do |result|
      subId = result["submission_id"].to_i
      @scores[subId] = {} unless @scores.key?(subId)

      @scores[subId][result["problem_id"].to_i] = {
        score: result["score"].to_f,
        feedback: result["feedback"],
        score_id: result["score_id"].to_i,
        released: Utilities.is_truthy?(result["released"]) ? 1 : 0
      }
    end

    # Check if we should include regrade as a function
    @autograded = @assessment.has_autograder?

    @repos = GithubIntegration.find_by(user_id: @cud.user.id)&.repositories

    return unless @assessment.invalid? && @cud.instructor?

    # If the assessment has validation errors, let the instructor know
    flash.now[:error] = "This assessment is invalid due to the following error(s):<br/>"
    flash.now[:error] += @assessment.errors.full_messages.join("<br/>")
    flash.now[:html_safe] = true
  end

  action_auth_level :history, :student

  def history
    # Remember the student ID in case the user wants visit the gradesheet
    session["gradeUser#{@assessment.id}"] = params[:cud_id] if params[:cud_id]

    @startTime = Time.current
    @effectiveCud = if @cud.instructor? && params[:cud_id]
                      @course.course_user_data.find(params[:cud_id])
                    else
                      @cud
                    end
    @submissions = @assessment.submissions.where(course_user_datum_id: @effectiveCud.id)
                              .order("version DESC")
    @extension = @assessment.extensions.find_by(course_user_datum_id: @effectiveCud.id)
    @problems = @assessment.problems

    results = @submissions.select("submissions.id AS submission_id",
                                  "problems.id AS problem_id",
                                  "scores.id AS score_id",
                                  "scores.*")
                          .joins("LEFT JOIN problems ON
        submissions.assessment_id = problems.assessment_id")
                          .joins("LEFT JOIN scores ON
        (submissions.id = scores.submission_id
        AND problems.id = scores.problem_id)")

    # Process them to get into a format we want.
    @scores = {}
    results.each do |result|
      subId = result["submission_id"].to_i
      @scores[subId] = {} unless @scores.key?(subId)

      @scores[subId][result["problem_id"].to_i] = {
        score: result["score"].to_f,
        feedback: result["feedback"],
        score_id: result["score_id"].to_i,
        released: Utilities.is_truthy?(result["released"]) ? 1 : 0, # converts 't' to 1, "f" to 0
      }
    end

    # Check if we should include regrade as a function
    @autograded = @assessment.has_autograder?

    return unless params[:partial]

    @partial = true
    render("history", layout: false) && return
  end

  action_auth_level :viewFeedback, :student

  def viewFeedback
    # User requested to view feedback on a score
    @score = @submission.scores.find_by(problem_id: params[:feedback])
    autograded_scores = @submission.scores.includes(:problem).where(grader_id: 0)
    # Checks whether at least one problem has finished being auto-graded
    finishedAutograding = @submission.scores.where.not(feedback: nil).where(grader_id: 0)
    @job_id = @submission["jobid"]
    @submission_id = params[:submission_id]

    # Autograding is not in-progress and no score is available
    if @score.nil?
      if !finishedAutograding.empty?
        redirect_to(action: "viewFeedback",
                    feedback: finishedAutograding.first.problem_id,
                    submission_id: params[:submission_id]) && return
      end

      if @job_id.nil?
        flash[:error] = "No feedback for requested score"
        redirect_to(action: "index") && return
      end
    end

    # Autograding is in-progress
    return if @score.nil?

    @jsonFeedback = parseFeedback(@score.feedback)

    raw_score_hash = scoreHashFromScores(autograded_scores) if @score.grader_id <= 0
    @scoreHash = parseScore(raw_score_hash) unless raw_score_hash.nil?

    if Archive.archive? @submission.handin_file_path
      @files = Archive.get_files @submission.handin_file_path
    end

    # get_correct_filename is protected, so we wrap around controller-specific call
    @get_correct_filename = ->(annotation) {
      get_correct_filename(annotation, @files, @submission)
    }
  end

  action_auth_level :getPartialFeedback, :student

  def getPartialFeedback
    job_id = params["job_id"].to_i

    # User requested to view feedback on a score
    if job_id.nil?
      flash[:error] = "Invalid job id"
      redirect_to(action: "index") && return
    end

    begin
      resp = get_job_status(job_id)

      if resp["is_assigned"]
        resp['partial_feedback'] = tango_get_partial_feedback(job_id)
      end
    rescue AutogradeError => e
      render json: { error: "Get partial feedback request failed: #{e}" },
             status: :internal_server_error
    else
      render json: resp.to_json
    end
  end

  # TODO: Take into account any modifications by :parseAutoresult and :modifySubmissionScores
  # We should probably read the final scores directly
  # See: assessment_autograde_core.rb's saveAutograde
  def parseScore(score_hash)
    total = 0
    return if score_hash.nil?

    if @jsonFeedback&.key?("_scores_order") == false
      @jsonFeedback["_scores_order"] = score_hash.keys
    end
    score_hash.keys.each do |k|
      total += score_hash[k].to_f if score_hash[k]
    end
    score_hash["_total"] = total
    score_hash
  end

  def parse_stages(jsonFeedbackHash)
    @result = true
    if jsonFeedbackHash.key?("stages")
      jsonFeedbackHash["stages"].each do |stage|
        if jsonFeedbackHash[stage].key?("_order") == false
          jsonFeedbackHash[stage]["_order"] = jsonFeedbackHash[stage].keys
        end
      end
    end
    @result
  end

  def parseFeedback(feedback)
    return if feedback.nil?

    lines = feedback.rstrip.lines
    feedback = lines[lines.length - 2]

    return unless valid_json_hash?(feedback)

    jsonFeedbackHash = JSON.parse(feedback)
    if jsonFeedbackHash.key?("_presentation") == false
      nil
    elsif jsonFeedbackHash["_presentation"] == "semantic" && !parse_stages(jsonFeedbackHash).nil?
      jsonFeedbackHash
    end
  end

  def valid_json_hash?(json)
    parsed = JSON.parse(json)
    parsed.is_a? Hash
  rescue JSON::ParserError, TypeError
    false
  end

  action_auth_level :reload, :instructor

  def reload
    @assessment.load_config_file
  rescue StandardError, SyntaxError => e
    @error = e
  # let the reload view render
  else
    flash[:success] = "Success: Assessment config file reloaded!"
    redirect_to(action: :show) && return
  end

  action_auth_level :edit, :instructor

  def edit
    # default to the basic tab
    params[:active_tab] ||= "basic"

    # make sure the 'active_tab' is a real tab
    unless %w[basic handin penalties problems advanced].include? params[:active_tab]
      params[:active_tab] = "basic"
    end

    @has_annotations = @assessment.submissions.any? { |s| !s.annotations.empty? }

    @is_positive_grading = @assessment.is_positive_grading

    # warn instructors if the assessment is configured to allow late submissions
    # but the settings do not make sense
    if @assessment.end_at > @assessment.due_at
      warn_messages = []
      if @assessment.max_grace_days == 0
        warn_messages << "- Max grace days = 0: students can't use grace days"
      end
      if @assessment.effective_late_penalty.value == 0
        warn_messages << "- Late penalty = 0: late submissions made \
                          without grace days are not penalized"
      end
      unless warn_messages.empty?
        flash.now[:notice] = "Late submissions are allowed, but<br>"
        flash.now[:notice] += warn_messages.join('<br>')
        flash.now[:notice] += "<br>Please make sure that this was intended."
        flash.now[:html_safe] = true
      end
    end

    # Used for the penalties tab
    @has_unlimited_submissions = @assessment.max_submissions == -1
    @has_unlimited_grace_days = @assessment.max_grace_days.nil?
    @uses_default_version_threshold = @assessment.version_threshold.nil?
    @uses_default_late_penalty = @assessment.late_penalty.nil?
    @uses_default_version_penalty = @assessment.version_penalty.nil?

    # make sure the penalties are set up
    # placed after the check above, so that effective_late_penalty displays the correct result
    @assessment.late_penalty ||= Penalty.new(kind: "points")
    @assessment.version_penalty ||= Penalty.new(kind: "points")
  end

  action_auth_level :update, :instructor
  def update
    uploaded_embedded_quiz_form = params[:assessment][:embedded_quiz_form]
    uploaded_config_file = params[:assessment][:config_file]
    unless uploaded_embedded_quiz_form.nil?
      @assessment.embedded_quiz_form_data = uploaded_embedded_quiz_form.read
      @assessment.save!
    end

    unless uploaded_config_file.nil?
      config_source = uploaded_config_file.read

      assessment_config_file_path = @assessment.unique_source_config_file_path
      File.open(assessment_config_file_path, "w") do |f|
        f.write(config_source)
      end

      begin
        @assessment.load_config_file
      rescue StandardError, SyntaxError => e
        @error = e
        render("reload") && return
      end
    end

    begin
      @assessment.update!(edit_assessment_params)
      flash[:success] = "Assessment configuration updated!"

      redirect_to(tab_index) && return
    rescue ActiveRecord::RecordInvalid
      flash[:error] = "Assessment configuration could not be updated.<br>"
      flash[:error] += @assessment.errors.full_messages.join("<br>")
      flash[:html_safe] = true

      redirect_to(tab_index) && return
    end
  end

  action_auth_level :releaseAllGrades, :instructor

  def releaseAllGrades
    # release all grades
    num_released = releaseMatchingGrades { |_| true }

    if num_released > 0
      flash[:success] =
        format("%<num_released>d %<plurality>s released.",
               num_released:,
               plurality: (num_released > 1 ? "grades were" : "grade was"))
    else
      flash[:error] = "No grades were released. They might have all already been released."
    end
    redirect_to action: "viewGradesheet"
  end

  action_auth_level :releaseSectionGrades, :course_assistant

  def releaseSectionGrades
    unless @cud.section? && !@cud.section.empty? && @cud.lecture && !@cud.lecture.empty?
      flash[:error] =
        "You haven't been assigned to a lecture and/or section. Please contact your instructor."
      redirect_to action: "index"
      return
    end

    num_released = releaseMatchingGrades do |submission, _|
      @cud.CA_of? submission.course_user_datum
    end

    if num_released > 0
      flash[:success] =
        format("%<num_released>d %<plurality>s released.",
               num_released:,
               plurality: (num_released > 1 ? "grades were" : "grade was"))
    else
      flash[:error] = "No grades were released. " \
                      "Either they were all already released or you "\
                      "might be assigned to a lecture " \
                      "and/or section that doesn't exist. Please contact an instructor."
    end
    redirect_to url_for(action: 'viewGradesheet', section: '1')
  end

  action_auth_level :withdrawAllGrades, :instructor

  def withdrawAllGrades
    @assessment.submissions.each do |submission|
      scores = submission.scores.where(released: true)
      scores.each do |score|
        score.released = false

        begin
          updateScore(@assessment.course.course_user_data, score)
        rescue ActiveRecord::RecordInvalid => e
          flash[:error] = flash[:error] || ""
          flash[:error] += "Unable to withdraw score for "\
                           "#{@assessment.course.course_user_data.user.email}: #{e.message}"
        end
      end
    end

    flash[:success] = "Grades have been withdrawn."
    redirect_to action: "viewGradesheet"
  end

  action_auth_level :writeup, :student

  def writeup
    # If the logic here changes, do update assessment#has_writeup?
    if @assessment.writeup_is_url?
      redirect_to @assessment.writeup
      return
    end

    if @assessment.writeup_is_file?
      # Note: writeup_is_file? validates that the writeup lies within the assessment folder
      filename = @assessment.writeup_path
      send_file(filename,
                type: mime_type_from_ext(File.extname(filename)),
                disposition: "inline",
                file: File.basename(filename))
      return
    end

    flash.now[:error] = "There is no writeup for this assessment."
  end

  # uninstall - uninstalls an assessment
  def uninstall(name)
    if name.blank?
      flash[:error] = "Name cannot be blank"
      return
    end
    @assessment.destroy
    f = Rails.root.join("assessmentConfig", "#{@course.name}-#{name}.rb")
    File.delete(f)
  end

protected

  # We only do this so that it can be overwritten by modules
  def updateScore(_user, score)
    score.save!
    true
  end

  # This does nothing on purpose
  def loadHandinPage; end

  def releaseMatchingGrades
    num_released = 0

    @assessment.problems.each do |problem|
      @assessment.submissions.find_each do |sub|
        next unless yield(sub, problem)

        score = problem.scores.where(submission_id: sub.id).first

        # if score already exists and isn't released, release it
        if score
          unless score.released
            score.released = true
            num_released += 1
          end

          # if score doesn't exist yet, create it and release it
        else
          score = problem.scores.new(submission: sub,
                                     released: true,
                                     grader: @cud)
          num_released += 1
        end

        updateScore(sub.course_user_datum_id, score)
      end
    end

    num_released
  end

private

  def new_assessment_params
    ass = params.require(:assessment)
    ass[:category_name] = params[:new_category] if params[:new_category].present?
    ass.permit(:name, :display_name, :category_name, :group_size, :github_submission_enabled,
               :allow_student_assign_group)
  end

  def edit_assessment_params
    ass = params.require(:assessment)
    ass[:category_name] = params[:new_category] if params[:new_category].present?

    if ass[:late_penalty_attributes] && ass[:late_penalty_attributes][:value].blank?
      ass.delete(:late_penalty_attributes)
      @assessment.late_penalty&.destroy
    end

    if ass[:version_penalty_attributes] && ass[:version_penalty_attributes][:value].blank?
      ass.delete(:version_penalty_attributes)
      @assessment.version_penalty&.destroy
    end

    if params[:unlimited_submissions].to_boolean == true
      ass[:max_submissions] = -1
    end

    if params[:unlimited_grace_days].to_boolean == true
      ass[:max_grace_days] = ""
    end

    if params[:use_default_late_penalty].to_boolean == true
      ass.delete(:late_penalty_attributes)
      @assessment.late_penalty&.destroy
    end

    if params[:use_default_version_penalty].to_boolean == true
      ass.delete(:version_penalty_attributes)
      @assessment.version_penalty&.destroy
    end

    if params[:use_default_version_threshold].to_boolean == true
      ass[:version_threshold] = ""
    end

    ass.delete(:name)
    ass.delete(:config_file)
    ass.delete(:embedded_quiz_form)

    ass.permit!
  end

  ##
  # a valid assessment tar has a single root directory that's named after the
  # assessment, containing an assessment yaml file
  #
  def valid_asmt_tar(tar_extract)
    asmt_name = nil
    asmt_yml_exists = false
    asmt_name_is_valid = true
    tar_extract.each do |entry|
      pathname = entry.full_name
      next if pathname.start_with? "."

      # Removes file created by Mac when tar'ed
      next if pathname.start_with? "PaxHeader"

      pathname.chomp!("/") if entry.directory?
      # nested directories are okay
      if entry.directory? && pathname.count("/") == 0
        if asmt_name
          flash[:error] = "Error in tarball: Found root directory #{asmt_name}
                           but also found root directory #{pathname}. Ensure
                           there is only one root directory in the tarball."
          return false
        end

        asmt_name = pathname
      else
        if !asmt_name
          flash[:error] = "Error in tarball: No root directory found."
          return false
        end

        if pathname == "#{asmt_name}/#{asmt_name}.rb"
          # We only ever read once, so no need to rewind after
          config_source = entry.read

          # validate syntax of config
          RubyVM::InstructionSequence.compile(config_source)
        end
        asmt_yml_exists = true if pathname == "#{asmt_name}/#{asmt_name}.yml"
      end
    end
    # it is possible that the assessment path does not match the
    # the expected assessment path when the Ruby config file
    # has a different name then the pathname
    if !asmt_name.nil? && asmt_name !~ Assessment::VALID_NAME_REGEX
      flash[:error] = "Errors found in tarball: Assessment name #{asmt_name} is invalid.
                       Find more information on valid assessment names "\
          '<a href="https://docs.autolabproject.com/lab/#assessment-naming-rules">here</a> <br>'
      flash[:html_safe] = true
      asmt_name_is_valid = false
    end
    if !(asmt_yml_exists && !asmt_name.nil?)
      flash[:error] = "Errors found in tarball:"
      if !asmt_yml_exists && !asmt_name.nil?
        flash[:error] += "<br>Assessment yml file #{asmt_name}/#{asmt_name}.yml was not found"
      end
    end
    [asmt_yml_exists && !asmt_name.nil? && asmt_name_is_valid, asmt_name]
  end

  def tab_index
    # Get the current tab's redirect path by checking the submit tag
    # which tells us which submit button in the edit form was clicked
    tab_name = "basic"
    if params[:handin]
      tab_name = "handin"
    elsif params[:penalties]
      tab_name = "penalties"
    elsif params[:problems]
      tab_name = "problems"
    elsif params[:advanced]
      tab_name = "advanced"
    end

    "#{edit_course_assessment_path(@course, @assessment)}/#tab_#{tab_name}"
  end

  def destroy_no_redirect(assessment)
    unless assessment.nil?
      @assessment = assessment
    end

    @assessment.submissions.each(&:destroy)

    @assessment.attachments.each(&:destroy)

    # Delete config file copy in assessmentConfig
    if File.exist? @assessment.config_file_path
      File.delete @assessment.config_file_path
    end
    if File.exist? @assessment.config_backup_file_path
      File.delete @assessment.config_backup_file_path
    end

    @assessment.destroy # awwww!!!!
  end

  def get_unimported_asmts_from_dir
    dir_path = @course.directory_path
    @unused_config_files = []
    Dir.foreach(dir_path) do |filename|
      # skip if not directory in folder
      next if !File.directory?(File.join(dir_path,
                                         filename)) || (filename == "..") || (filename == ".")

      # assessment names must be only lowercase letters and digits
      if filename !~ Assessment::VALID_NAME_REGEX
        # add line break if adding to existing error message
        flash.now[:error] = flash.now[:error] ? "#{flash.now[:error]} <br>" : ""
        flash.now[:error] += "An error occurred while trying to display an existing assessment " \
            "from file directory #{filename}: Invalid assessment name. "\
            "Find more information on valid assessment names "\
            '<a href="https://docs.autolabproject.com/lab/#assessment-naming-rules">here</a><br>'
        flash.now[:html_safe] = true
        next
      end

      # each assessment must have an associated yaml file,
      # and it must have a name field that matches its filename
      unless File.exist?(File.join(dir_path, filename, "#{filename}.yml"))
        flash.now[:error] = flash.now[:error] ? "#{flash.now[:error]} <br>" : ""
        flash.now[:error] += "An error occurred while trying to display an existing assessment " \
          "from file directory #{filename}: #{filename}.yml does not exist"
        flash.now[:html_safe] = true
        next
      end

      # Only list assessments that aren't installed yet
      assessment_exists = @course.assessments.exists?(name: filename)
      @unused_config_files << filename unless assessment_exists
    end
    @unused_config_files.sort!
  end

  def scoreHashFromScores(scores)
    scores.map { |s|
      [s.problem.name, s.score]
    }.to_h
  end

  def set_install_asmt_breadcrumb
    return if @course.nil?

    @breadcrumbs << (view_context.link_to "Install Assessment",
                                          install_assessment_course_assessments_path(@course))
  end
end
