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

  rescue_from ActionView::MissingTemplate do |_exception|
    redirect_to("/home/error_404")
  end

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
                                            importAsmtFromTar importAssessment
                                            log_submit local_submit autograde_done]
  before_action :set_submission, only: [:viewFeedback]

  # We have to do this here, because the modules don't inherit ApplicationController.

  # Grading
  action_auth_level :bulkGrade, :course_assistant
  action_auth_level :quickSetScore, :course_assistant
  action_auth_level :quickSetScoreDetails, :course_assistant
  action_auth_level :submission_popover, :course_assistant
  action_auth_level :score_grader_info, :course_assistant
  action_auth_level :viewGradesheet, :course_assistant
  action_auth_level :viewGradesheet2, :course_assistant
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

  # SVN
  autolab_require Rails.root.join("app/controllers/assessment/svn.rb")
  include AssessmentSVN
  action_auth_level :admin_svn, :instructor
  action_auth_level :set_repo, :instructor
  action_auth_level :import_svn, :instructor

  def index
    @is_instructor = @cud.has_auth_level? :instructor
    announcements_tmp = Announcement.where("start_date < :now AND end_date > :now",
                                           now: Time.current)
                                    .where(persistent: false)
    @announcements = announcements_tmp.where(course_id: @course.id)
                                      .or(announcements_tmp.where(system: true)).order(:start_date)
    @attachments = if @cud.instructor?
                     @course.attachments
                   else
                     # Attachments that are released, and whose related assessment is also released
                     course_attachments = @course.attachments
                                                 .where(released: true)
                                                 .left_outer_joins(:assessment)

                     # Either assessment_id is nil (i.e. course attachment)
                     # Or the assessment has started
                     course_attachments.where(assessment_id: nil)
                                       .or(course_attachments.where("assessments.start_at < ?",
                                                                    Time.current))
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
    ass_dir = Rails.root.join("courses", @course.name)
    @unused_config_files = []
    Dir.foreach(ass_dir) do |filename|
      # skip if not directory in folder
      next if !File.directory?(File.join(ass_dir,
                                         filename)) || (filename == "..") || (filename == ".")

      # assessment names must be only lowercase letters and digits
      if filename =~ /[^a-z0-9]/
        # add line break if adding to existing error message
        flash.now[:error] = flash.now[:error] ? "#{flash.now[:error]} <br>" : ""
        flash.now[:error] += "An error occurred while trying to display an existing assessment " \
            "on file directory #{filename}: assessment file names must only contain lowercase " \
            "letters and digits with no spaces"
        flash.now[:html_safe] = true
        next
      end

      # each assessment must have an associated yaml file
      unless File.exist?(File.join(ass_dir, filename, "#{filename}.yml"))
        flash.now[:error] = flash.now[:error] ? "#{flash.now[:error]} <br>" : ""
        flash.now[:error] += "An error occurred while trying to display an existing assessment " \
          "on file directory #{filename}: #{filename}.yml does not exist"
        flash.now[:html_safe] = true
        next
      end

      # Only list assessments that aren't installed yet
      assessment_exists = @course.assessments.exists?(name: filename)
      @unused_config_files << filename unless assessment_exists
    end
    @unused_config_files.sort!
  end

  action_auth_level :importAsmtFromTar, :instructor

  def importAsmtFromTar
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
          "assessment yaml file and an assessment ruby file."
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
    unless @course.assessments.find_by(name: asmt_name).nil?
      flash[:error] =
        "An assessment with the same name already exists for the course. "\
        "Please use a different name."
      redirect_to(action: "install_assessment") && return
    end

    # If all requirements are satisfied, extract assessment files.
    begin
      course_root = Rails.root.join("courses", @course.name)
      assessment_path = Rails.root.join("courses", @course.name, asmt_name)
      tar_extract.rewind
      tar_extract.each do |entry|
        relative_pathname = entry.full_name
        entry_file = File.join(course_root, relative_pathname)
        # Ensure file will lie within course, otherwise skip
        next unless Archive.in_dir?(Pathname(entry_file), Pathname(assessment_path))

        if entry.directory?
          FileUtils.mkdir_p(entry_file,
                            mode: entry.header.mode, verbose: false)
        elsif entry.file?
          FileUtils.mkdir_p(File.join(course_root, File.dirname(relative_pathname)),
                            mode: entry.header.mode, verbose: false)
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

    params[:assessment_name] = asmt_name
    importAssessment && return
  end

  # importAssessment - Imports an existing assessment from local file.
  # The main task of this function is to decide what category a newly
  # installed assessment should be assigned to.
  action_auth_level :importAssessment, :instructor

  def importAssessment
    @assessment = @course.assessments.new(name: params[:assessment_name])
    assessment_path = Rails.root.join("courses/#{@course.name}/#{@assessment.name}")
    # not sure if this check is 100% necessary anymore, but is a last resort
    # against creating an invalid assessment
    if params[:assessment_name] != @assessment.name
      flash[:error] = "Error creating assessment: Config module is named #{@assessment.name}
                       but assessment file name is #{params[:assessment_name]}"
      # destroy model
      destroy_no_redirect
      # need to delete explicitly b/c the paths don't match
      FileUtils.rm_rf(assessment_path)
      redirect_to(install_assessment_course_assessments_path(@course)) && return
    end

    begin
      @assessment.load_yaml # this will save the assessment
    rescue StandardError => e
      flash[:error] = "Error loading yaml: #{e}"
      destroy_no_redirect
      # need to delete explicitly b/c the paths don't match
      FileUtils.rm_rf(assessment_path)
      redirect_to(install_assessment_course_assessments_path(@course)) && return
    end
    @assessment.load_embedded_quiz # this will check and load embedded quiz
    @assessment.construct_folder # make sure there's a handin folder, just in case
    begin
      @assessment.load_config_file # only call this on saved assessments
    rescue StandardError => e
      flash[:error] = "Error loading config module: #{e}"
      destroy_no_redirect
      # need to delete explicitly b/c the paths don't match
      FileUtils.rm_rf(assessment_path)
      redirect_to(install_assessment_course_assessments_path(@course)) && return
    end
    flash[:success] = "Successfully imported #{@assessment.name}"
    redirect_to([@course, @assessment])
  end

  # create - Creates an assessment from an assessment directory
  # residing in the course directory.
  action_auth_level :create, :instructor

  def create
    @assessment = @course.assessments.new(new_assessment_params)

    if @assessment.name.blank?
      # Validate the name
      ass_name = @assessment.display_name.downcase.gsub(/[^a-z0-9]/, "")

      if ass_name.blank?
        flash[:error] =
          "Assessment name is blank or contains characters that are not lowercase letters or digits"
        redirect_to(action: :install_assessment)
        return
      end

      # Update name in object
      @assessment.name = ass_name
    end

    # fill in other fields
    @assessment.course = @course
    @assessment.handin_directory = "handin"

    @assessment.handin_filename = if @assessment.github_submission_enabled
                                    "handin.tgz"
                                  else
                                    "handin.c"
                                  end

    @assessment.visible_at = Time.current + 1.day
    @assessment.start_at = Time.current + 1.day
    @assessment.due_at = Time.current + 1.day
    @assessment.end_at = Time.current + 1.day
    @assessment.grading_deadline = Time.current + 1.day
    @assessment.quiz = false
    @assessment.quizData = ""
    @assessment.max_submissions = params.include?(:max_submissions) ? params[:max_submissions] : -1

    if @assessment.embedded_quiz
      begin
        @assessment.embedded_quiz_form_data = params[:assessment][:embedded_quiz_form].read
      rescue StandardError
        flash[:error] = "Embedded quiz form cannot be empty!"
        redirect_to(action: :install_assessment)
        return
      end
    end

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
    @course.reload_course_config

    redirect_to([@course, @assessment]) && return
  end

  def assessmentInitialize(assignName)
    @assessment = @course.assessments.find_by(name: assignName)
    raise "Assessment #{assignName} does not exist!" unless @assessment

    if @assessment.nil?
      flash[:error] = "Error: Invalid assessment"
      redirect_to([@course, :assessments]) && return
    end

    @name = @assessment.name
    @description = @assessment.description
    @start_at = @assessment.start_at
    @due_at = @assessment.due_at
    @end_at = @assessment.end_at
    @visible_at = @assessment.visible_at
    @id = @assessment.id
  end

  # installProblems - If there are no problems defined yet for this
  # assessment, then create them using the list defined by the #
  # assessmentInitialize() function in the user's assessment.rb
  # file.
  #
  # Note: this is only here for backward compatibility. In the
  # current system, problems definitions are imported from the
  # assessment properties yaml file.
  def installProblems
    redirect_to(action: "index") && return unless @cud.instructor?

    return unless @assessment.problems.count == 0

    @problems.each do |problem|
      @assessment.problems.create do |p|
        p.name = problem["name"]
        p.description = problem["description"]
        p.max_score = problem["max_score"]
        p.optional = problem["optional"]
      end
    end
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
    base_path = Rails.root.join("courses", @course.name).to_s
    asmt_dir = @assessment.name
    begin
      # Update the assessment config YAML file.
      @assessment.dump_yaml
      # Save embedded_quiz
      @assessment.dump_embedded_quiz
      # Pack assessment directory into a tarball.
      tarStream = StringIO.new("")
      Gem::Package::TarWriter.new(tarStream) do |tar|
        tar.mkdir asmt_dir, File.stat(File.join(base_path, asmt_dir)).mode
        Dir[File.join(base_path, asmt_dir, "**")].each do |file|
          mode = File.stat(file).mode
          relative_path = file.sub(%r{^#{Regexp.escape base_path}/?}, "")

          if File.directory?(file)
            tar.mkdir relative_path, mode
          elsif !relative_path.starts_with? File.join(@assessment.name,
                                                      @assessment.handin_directory)
            tar.add_file relative_path, mode do |tarFile|
              File.open(file, "rb") { |f| tarFile.write f.read }
            end
          end
        end
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

    name = @assessment.display_name
    @assessment.destroy # awwww!!!!
    flash[:success] = "The assessment #{name} has been deleted."
    redirect_to(course_path(@course)) && return
  end

  action_auth_level :show, :student

  def show
    set_handin
    extend_config_module(@assessment, @submission, @cud)

    @aud = @assessment.aud_for @cud.id

    @list = {}
    @list_title = {}

    if @assessment.overwrites_method?(:listOptions)
      list = @list
      @list = @assessment.config_module.listOptions(list)
    end

    # Remember the student ID in case the user wants visit the gradesheet
    session["gradeUser#{@assessment.id}"] = params[:cud_id] if params[:cud_id]

    @startTime = Time.current
    @effectiveCud = if @cud.instructor? && params[:cud_id]
                      @course.course_user_data.find(params[:cud_id])
                    else
                      @cud
                    end
    @attachments = if @cud.instructor?
                     @assessment.attachments
                   else
                     @assessment.attachments.where(released: true)
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
    # Checks whether at least one problem has finished being auto-graded
    @finishedAutograding = @submission.scores.where.not(feedback: nil).where(grader_id: 0)
    @job_id = @submission["jobid"]
    @submission_id = params[:submission_id]

    # Autograding is not in-progress and no score is available
    if @score.nil?
      if !@finishedAutograding.empty?
        redirect_to(action: "viewFeedback",
                    feedback: @finishedAutograding.first.problem_id,
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
    @scoreHash = parseScore(@score.feedback)
    if Archive.archive? @submission.handin_file_path
      @files = Archive.get_files @submission.handin_file_path
    end
    @problemReleased = @submission.scores.pluck(:released).all? &&
                       !@assessment.before_grading_deadline?
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

  def parseScore(feedback)
    return if feedback.nil?

    lines = feedback.lines
    feedback = lines[lines.length - 1].chomp

    return unless valid_json?(feedback)

    score_hash = JSON.parse(feedback)
    score_hash = score_hash["scores"]
    if @jsonFeedback&.key?("_scores_order") == false
      @jsonFeedback["_scores_order"] = score_hash.keys
    end
    @total = 0
    score_hash.keys.each do |k|
      @total += score_hash[k]
    end
    score_hash["_total"] = @total
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

    lines = feedback.lines
    feedback = lines[lines.length - 2]&.chomp

    return unless valid_json?(feedback)

    jsonFeedbackHash = JSON.parse(feedback)
    if jsonFeedbackHash.key?("_presentation") == false
      nil
    elsif jsonFeedbackHash["_presentation"] == "semantic" && !parse_stages(jsonFeedbackHash).nil?
      jsonFeedbackHash
    end
  end

  def valid_json?(json)
    JSON.parse(json)
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

    # make sure the penalties are set up
    @assessment.late_penalty ||= Penalty.new(kind: "points")
    @assessment.version_penalty ||= Penalty.new(kind: "points")

    @has_annotations = @assessment.submissions.any? { |s| !s.annotations.empty? }

    @is_positive_grading = @assessment.is_positive_grading
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

      assessment_config_file_path = @assessment.source_config_file_path
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
    rescue ActiveRecord::RecordInvalid => e
      flash[:error] = e.message.sub!("Validation failed: ", "")

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
               num_released: num_released,
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
               num_released: num_released,
               plurality: (num_released > 1 ? "grades were" : "grade was"))
    else
      flash[:error] = "No grades were released. " \
                      "Either they were all already released or you "\
                      "might be assigned to a lecture " \
                      "and/or section that doesn't exist. Please contact an instructor."
    end
    redirect_to action: "viewGradesheet"
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
    ass.permit(:name, :display_name, :category_name, :has_svn, :has_lang, :group_size,
               :embedded_quiz, :embedded_quiz_form_data, :github_submission_enabled)
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

    ass.delete(:name)
    ass.delete(:config_file)

    ass.permit!
  end

  ##
  # a valid assessment tar has a single root directory that's named after the
  # assessment, containing an assessment yaml file and an assessment ruby file
  #
  def valid_asmt_tar(tar_extract)
    asmt_name = nil
    asmt_rb_exists = false
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
        return false if asmt_name

        asmt_name = pathname
      else
        return false unless asmt_name

        if pathname == "#{asmt_name}/#{asmt_name}.rb"
          # We only ever read once, so no need to rewind after
          config_source = entry.read

          # validate syntax of config
          RubyVM::InstructionSequence.compile(config_source)

          asmt_rb_exists = true
        end
        asmt_yml_exists = true if pathname == "#{asmt_name}/#{asmt_name}.yml"
      end
    end
    # it is possible that the assessment path does not match the
    # the expected assessment path when the Ruby config file
    # has a different name then the pathname
    if !asmt_name.nil? && asmt_name =~ /[^a-z0-9]/
      flash[:error] = "Errors found in tarball: Assessment name #{asmt_name} is invalid.
                       Assessment file names must only contain lowercase
                       letters and digits with no spaces."
      asmt_name_is_valid = false
    end
    if !(asmt_rb_exists && asmt_yml_exists && !asmt_name.nil?)
      flash[:error] = "Errors found in tarball:"
      if !asmt_yml_exists && !asmt_name.nil?
        flash[:error] += "<br>Assessment yml file #{asmt_name}/#{asmt_name}.yml was not found"
      end
      if !asmt_rb_exists && !asmt_name.nil?
        flash[:error] += "<br>Assessment rb file #{asmt_name}/#{asmt_name}.rb was not found"
      end
    end
    [asmt_rb_exists && asmt_yml_exists && !asmt_name.nil? && asmt_name_is_valid, asmt_name]
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

  def destroy_no_redirect
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
end
