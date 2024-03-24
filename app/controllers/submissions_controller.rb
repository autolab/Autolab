require "archive"
require "pdf"
require "prawn"
require "json"
require "tempfile"

class SubmissionsController < ApplicationController
  # inherited from ApplicationController
  before_action :set_assessment
  before_action :set_assessment_breadcrumb
  before_action :set_manage_submissions_breadcrumb, except: %i[index]
  before_action :set_submission, only: %i[destroy destroyConfirm download edit update
                                          view release_student_grade unrelease_student_grade]
  before_action :get_submission_file, only: %i[download view]

  action_auth_level :index, :instructor
  def index
    @submissions = @assessment.submissions.includes({ course_user_datum: :user })
                              .order("created_at DESC")
    @autograded = @assessment.has_autograder?
  end

  action_auth_level :new, :instructor
  def new
    @submission = @assessment.submissions.new(tweak: Tweak.new)

    if !params["course_user_datum_id"].nil?
      cud_ids = params["course_user_datum_id"].split(",")
      begin
        @cuds = @course.course_user_data.find(cud_ids)
      rescue ActiveRecord::RecordNotFound
        flash[:error] = "Couldn't find all course_user_data IDs in #{cud_ids}. " \
          "Make sure the CUD ids are correct."
        redirect_to(course_assessment_submissions_path(@course, @assessment))
      end
    else
      @users, @usersEncoded = @course.get_autocomplete_data
    end
  end

  action_auth_level :create, :instructor
  def create
    if params[:submission].nil? || params[:submission][:course_user_datum_id].nil? ||
       !params[:submission][:course_user_datum_id].is_a?(String) ||
       params[:submission][:tweak_attributes].nil? ||
       params[:submission]["notes"].nil?
      flash[:error] = "Could not create submission: submission params not well formed"
      redirect_to(course_assessment_submissions_path(@course, @assessment)) && return
    end
    @submission = @assessment.submissions.new
    cud_ids = params[:submission][:course_user_datum_id].split(",")
    # Validate all users before we start
    begin
      @cuds = @course.course_user_data.find(cud_ids)
    rescue ActiveRecord::RecordNotFound
      flash[:error] = "Invalid CourseUserDatum ID in #{cud_ids}"
      redirect_to(course_assessment_submissions_path(@course, @assessment)) && return
    end

    cud_ids.each do |cud_id|
      @submission = Submission.new(assessment_id: @assessment.id)
      @submission.course_user_datum_id = cud_id
      @submission.notes = params[:submission]["notes"]
      if params[:submission][:tweak_attributes][:value].present?
        @submission.tweak = Tweak.new(params[:submission][:tweak_attributes].permit(%i[value kind
                                                                                       _destroy]))
      end
      @submission.special_type = params[:submission]["special_type"]
      @submission.submitted_by_id = @cud.id
      begin
        @submission.save! # Now we have a version number!
      rescue ActiveRecord::RecordInvalid
        flash[:error] =
          "There were errors creating the submission for student "  \
        "#{@submission.course_user_datum.email}"
        @submission.errors.full_messages.each do |msg|
          flash[:error] += "<br>#{msg}"
        end
        flash[:html_safe] = true
        redirect_to(course_assessment_submissions_path(@course, @assessment)) && return
      end
      if params[:submission]["file"].present?
        @submission.save_file(params[:submission])
      end
    end
    flash[:success] =
      "#{ActionController::Base.helpers.pluralize(cud_ids.size, 'Submission')} Created"
    redirect_to course_assessment_submissions_path(@course, @assessment)
  end

  action_auth_level :edit, :instructor
  def edit
    @submission.tweak ||= Tweak.new
  end

  action_auth_level :update, :instructor
  def update
    if @submission.nil? ||
       params[:submission].nil? ||
       params[:submission][:tweak_attributes].nil? ||
       params[:submission]["notes"].nil?
      flash[:error] = "Could not update submission: submission params not well formed"
      redirect_to(course_assessment_submissions_path(@course, @assessment)) && return
    end

    if params[:submission][:tweak_attributes][:value].blank?
      params[:submission][:tweak_attributes][:_destroy] = true
    end

    if @submission.update(edit_submission_params)
      flash[:success] = "Submission successfully updated"
      redirect_to(course_assessment_submissions_path(@course, @assessment)) && return
    end

    # Error case
    flash[:error] = "Error: There were errors updating the submission for student " \
        "#{@submission.course_user_datum.email}"
    @submission.errors.full_messages.each do |msg|
      flash[:error] += "<br>#{msg}"
    end
    flash[:html_safe] = true
    redirect_to(edit_course_assessment_submission_path(@submission.course_user_datum.course,
                                                       @assessment, @submission))
  end

  action_auth_level :destroy, :instructor
  def destroy
    if @submission.destroy
      flash[:success] = "Submission successfully destroyed"
    else
      flash[:error] = "Submission failed to be destroyed"
    end
    redirect_to(course_assessment_submissions_path(@submission.course_user_datum.course,
                                                   @submission.assessment))
  end

  # page to show to instructor to confirm that they would like to
  # remove a given submission for a student
  action_auth_level :destroyConfirm, :instructor
  def destroyConfirm; end

  ##
  ## THIS MARKS THE END OF RESTful ROUTES
  ##

  # TODONE?  THIS MAY DELETE MOST OF YOUR USERS.  USE WITH CAUTION.
  action_auth_level :missing, :instructor
  def missing
    @submissions = @assessment.submissions

    cuds = @course.students.to_a
    @missing = []

    @submissions.each do |submission|
      cuds.delete(submission.course_user_datum)
    end

    cuds.each_with_index do |c, i|
      @missing[i] = {}
      @missing[i][:id] = c.id
      @missing[i][:email] = c.email
      @missing[i][:aud] = AssessmentUserDatum.get @assessment.id, c.id
    end
  end

  # should be okay, but untested
  action_auth_level :downloadAll, :course_assistant
  def downloadAll
    failure_redirect_path = if @cud.course_assistant
                              course_assessment_path(@course, @assessment)
                            else
                              course_assessment_submissions_path(@course, @assessment)
                            end

    unless @assessment.valid?
      flash[:error] = "The assessment has errors which must be rectified."
      @assessment.errors.full_messages.each do |msg|
        flash[:error] += "<br>#{msg}"
      end
      flash[:html_safe] = true
      redirect_to failure_redirect_path and return
    end

    if @assessment.disable_handins
      flash[:error] = "There are no submissions to download."
      redirect_to failure_redirect_path and return
    end

    submissions = if params[:final]
                    @assessment.submissions.latest.includes(:course_user_datum)
                  else
                    @assessment.submissions.includes(:course_user_datum)
                  end

    submissions = submissions.select do |s|
      p = s.handin_file_path
      @cud.can_administer?(s.course_user_datum) && !p.nil? && File.exist?(p) && File.readable?(p)
    end
    filedata = submissions.collect do |s|
      p = s.handin_file_path
      email = s.course_user_datum.user.email
      [p, download_filename(p, email)]
    end

    result = Archive.create_zip filedata # result is stringIO to be sent

    if result.nil?
      flash[:error] = "There are no submissions to download."
      redirect_to failure_redirect_path and return
    end

    send_data(result.read, # to read from stringIO object returned by create_zip
              type: "application/zip",
              disposition: "attachment", # tell browser to download
              filename: "#{@course.name}_#{@course.semester}_#{@assessment.name}_submissions.zip")
  end

  # Action to be taken when the user wants do download a submission but
  # not actually view it. If the :header_position parameter is set, it will
  # try to send the file at that position in the archive.
  action_auth_level :download, :student
  def download
    if Archive.archive?(@filename) && params[:header_position]
      file, pathname = Archive.get_nth_file(@filename, params[:header_position].to_i)
      unless file && pathname
        flash[:error] = "Could not read archive."
        redirect_to course_assessment_path(@course, @assessment) and return
      end

      send_data file,
                filename: pathname,
                disposition: "inline"

    elsif params[:annotated]
      # Only show annotations if grades have been released or the user is an instructor
      @annotations = []
      if @submission.grades_released?(@cud)
        @annotations = @submission.annotations.to_a
      end

      Prawn::Document.generate(@filename_annotated, template: @filename) do |pdf|
        @annotations.each do |annotation|
          next if annotation.coordinate.nil?

          position = annotation.coordinate.split(",")
          page  = position[2].to_i

          width = position[3].to_f * pdf.bounds.width
          height = position[4].to_f * pdf.bounds.height

          xCord = position[0].to_f * pdf.bounds.width
          yCord = pdf.bounds.height - (position[1].to_f * pdf.bounds.height)

          value = "N/A"
          value = annotation.value if annotation.value.present?

          problem = annotation.problem if annotation.problem
          problem_name = "General"
          problem_name = problem.name unless problem.nil?

          comment = "#{annotation.comment}\n\nProblem: #{problem_name}\nScore: #{value}"

          # + 1 since pages are indexed 1-based
          pdf.go_to_page(page + 1)

          # Creates a text annotation/pdf comment on the pdf itself.
          # 10 and 55 numbers in this case to shift the comment
          # to where the cursor was clicked by the annotator
          ary = [xCord + 10, yCord + 55, width, height]
          pdf.text_annotation(ary, comment)
        end
      end

      send_file @filename_annotated,
                filename: @basename_annotated,
                disposition: "inline"

    else
      send_file @filename,
                filename: @basename,
                disposition: "inline"
    end
  end

  # Action to be taken when the user wants to view a particular file.
  # Tries to highlight its syntax when possible. If the :header_position
  # parameter is set, it will try to send the file at that position in
  # archive.
  action_auth_level :view, :student
  def view
    flash[:error] = "Cannot manage nil course" if @course.nil?

    # Pull the files with their hierarchy info for the file tree
    if Archive.archive? @filename
      begin
        @files = Archive.get_file_hierarchy(@filename).sort! do |a, b|
          a[:pathname] <=> b[:pathname]
        end
        @header_position = params[:header_position].to_i
      rescue StandardError
        flash[:error] = "Could not read archive."
        redirect_to course_assessment_path(@course, @assessment) and return false
      end
    else
      @files = [{
        pathname: @filename,
        header_position: 0,
        mac_bs_file: @filename.include?("__MACOSX") ||
          @filename.include?(".DS_Store") ||
          @filename.include?(".metadata"),
        directory: Archive.looks_like_directory?(@filename)
      }]
    end

    viewing_autograder_output = params.include?(:header_position) &&
                                (params[:header_position].to_i == -1)

    # We are mapping autograder output to header_position -1
    # If it doesn't exist, we will display a message accordingly
    @files.prepend({ pathname: "Autograder Output",
                     header_position: -1,
                     mac_bs_file: false,
                     directory: false })

    if viewing_autograder_output
      file = get_autograder_output(@submission)
      @displayFilename = "Autograder Output"
    elsif params.include?(:header_position) && Archive.archive?(@submission.handin_file_path)
      file, pathname = Archive.get_nth_file(@submission.handin_file_path,
                                            params[:header_position].to_i)
      file = "" if file.nil?

      unless file && pathname
        flash[:error] = "Could not read archive."
        redirect_to course_assessment_path(@course, @assessment) and return false
      end

      @displayFilename = pathname
    else
      # auto-set header position for archives
      if Archive.archive?(@submission.handin_file_path)
        firstFile = Archive.get_files(@submission.handin_file_path).find do |archive_file|
          archive_file[:mac_bs_file] == false and archive_file[:directory] == false
        end || { header_position: 0 }
        redirect_to(view_course_assessment_submission_path(
                      @course, @assessment, @submission,
                      header_position: firstFile[:header_position]
                    )) && return

      # redirect to header_pos = 0, which is the first file,
      # if there's autograder and no header_position
      elsif !@submission.autograde_file.nil? && !params.include?(:header_position)
        redirect_to(view_course_assessment_submission_path(
                      @course, @assessment, @submission,
                      header_position: 0
                    )) && return
      end

      file = @submission.handin_file.read
      @displayFilename = @submission.filename
    end

    return unless file

    @file_contents = file # Keep this for the diff viewer
    file = "Binary file not displayed" if is_binary_file?(file)

    unless PDF.pdf?(file)
      # begin
      @data = @submission.annotated_file(file, @filename, params[:header_position])
      # Try extracting a symbol tree
      begin
        codePath = @filename
        if Archive.archive?(@submission.handin_file_path)
          # If the submission is an archive, write the open file's code
          # to a temp file so we can pass it into ctags

          ctagFile = Tempfile.new(["autolab_ctag", File.extname(pathname)])
          ctagFile.write(file)
          ctagFile.close
          codePath = ctagFile.path
        end
        # Special case -- we're using a CMU-specific language, and we need to
        # force the language interpretation
        @ctags_json =
          if (codePath.last(3) == ".c0") || (codePath.last(3) == ".c1")
            `ctags --output-format=json --language-force=C --fields="Nnk" #{codePath}`.split("\n")
          else
            # General case -- language can be inferred from file extension
            `ctags --extras=+q --output-format=json --fields="Nnk" #{codePath}`.split("\n")
          end
        @ctag_obj = []
        i = 0
        while i < @ctags_json.length
          obj_temp = JSON.parse(@ctags_json[i])
          if ((obj_temp["kind"] == "function") ||
            (obj_temp["kind"] == "method")) &&
             (@ctag_obj.select do |ctag|
                ctag["line"] == obj_temp["line"]
              end).empty?

            @ctag_obj.push(obj_temp)
          end
          i += 1

          next unless obj_temp["kind"] == "class"

          obj_temp = JSON.parse(@ctags_json[i])
          while (i + 1 < @ctags_json.length) &&
                ((obj_temp["kind"] == "member") || (obj_temp["kind"] == "method"))

            obj_exists = @ctag_obj.select { |ctag| ctag["line"] == obj_temp["line"] }
            if obj_exists.empty?
              @ctag_obj.push(obj_temp)
            # we want the obj with the extra class-qualified tag entry, 'class.function'
            elsif obj_temp["name"].length > obj_exists[0]["name"].length
              @ctag_obj[@ctag_obj.index(obj_exists[0])] = obj_temp
            end
            i += 1
            obj_temp = JSON.parse(@ctags_json[i])
          end
        end

        # The functions are in some arbitrary order, so sort them
        @ctag_obj = @ctag_obj.sort_by { |obj| obj["line"].to_i }
      rescue StandardError
        Rails.logger.error("Ctags not installed or failed")
      ensure
        ctagFile.unlink if defined?(ctagFile) && !ctagFile.nil?
      end

      begin
        # replace tabs with 4 spaces
        (0...@data.length).each do |k|
          @data[k][0].gsub!("\t", " " * 4)
        end
      rescue ArgumentError => e
        raise e unless e.message == "invalid byte sequence in UTF-8"

        flash[:error] =
          "Sorry, we could not parse your file because it contains non-ASCII characters."\
          " Please download file to view the source."
        redirect_to(:back) && return
      end
    end

    @annotations = @submission.annotations.to_a
    unless @submission.group_key.empty?
      group_submissions = @submission.group_associated_submissions
      group_submissions.each do |group_submission|
        @annotations += group_submission.annotations.to_a
      end
    end
    @annotations.sort! { |a, b| a.line.to_i <=> b.line.to_i }

    # Only show annotations if grades have been released or the user is an instructor
    unless @submission.grades_released?(@cud)
      @annotations = []
    end

    files = if Archive.archive? @filename
              Archive.get_files(@filename)
            end

    @problems = @assessment.problems.ordered.to_a

    # Allow scores to be assessed by the view
    @scores = Score.where(submission_id: @submission.id)

    # Used in _annotation_pane.html.erb
    @problemAnnotations = {}
    @problemMaxScores = {}
    @problemScores = {}
    @problemNameToId = {}
    autogradedProblems = {}

    @scores.each do |score|
      if score.grader_id == 0
        autogradedProblems[score.problem_id] = nil
      end
    end

    # initialize all problems
    @problems.each do |problem|
      # exclude problems that were autograded
      # so that we do not render the header in the annotation pane
      next if autogradedProblems.key? problem.id

      @problemAnnotations[problem.name] ||= []
      @problemMaxScores[problem.name] ||= problem.max_score
      @problemScores[problem.name] ||= 0
      @problemNameToId[problem.name] ||= problem.id
    end

    # extract information from annotations
    @annotations.each do |annotation|
      description = annotation.comment
      value = annotation.value || 0
      line = annotation.line
      problem = if annotation.problem
                  annotation.problem.name
                else
                  annotation.problem_id ? "Deleted Problem(s)" : "Global"
                end
      shared = annotation.shared_comment
      global = annotation.global_comment
      filename = get_correct_filename(annotation, files, @submission)

      # To handle annotations on deleted problems
      @problemAnnotations[problem] ||= []
      @problemMaxScores[problem] ||= 0
      @problemScores[problem] ||= 0
      @problemNameToId[problem] ||= -1

      @problemAnnotations[problem] << [description, value, line, annotation.submitted_by,
                                       annotation.id, annotation.position, filename, shared, global]
      @problemScores[problem] += value
    end

    # Process @problemSummaries
    # Group into global annotations, sorted by id
    # and file annotations, sorted by filename, followed by line, and then grouped by filename
    @problemAnnotations.each do |problem, descriptTuples|
      # group by global (a[8])
      annotations_by_type = descriptTuples.group_by { |a| a[8] }

      global_annotations = annotations_by_type[true] || []
      # sort by id (a[4])
      global_annotations = global_annotations.sort_by { |a| a[4] }

      annotations_by_file = annotations_by_type[false] || []
      # sort by filename (a[6]), followed by line (a[2]) and group by filename (a[6])
      annotations_by_file = annotations_by_file.sort_by{ |a| [a[6], a[2]] }.group_by { |a| a[6] }

      @problemAnnotations[problem] = {
        global_annotations:,
        annotations_by_file:
      }
    end

    @latestSubmissions = @assessment.assessment_user_data
                                    .map(&:latest_submission)
                                    .reject(&:nil?)
                                    .sort_by{ |submission| submission.course_user_datum.user.email }
    @curSubmissionIndex = @latestSubmissions.index do |submission|
      submission.course_user_datum.user.email == @submission.course_user_datum.user.email
    end
    # Previous and next student
    @prevSubmission = if @curSubmissionIndex > 0
                        @latestSubmissions[@curSubmissionIndex - 1]
                      end
    @nextSubmission = if @curSubmissionIndex < (@latestSubmissions.size - 1)
                        @latestSubmissions[@curSubmissionIndex + 1]
                      end

    @userVersions = @assessment.submissions
                               .where(course_user_datum_id: @submission.course_user_datum_id)
                               .order("version DESC")

    if viewing_autograder_output
      # Autograder Output is a dummy file
      # If we are viewing autograder output, just don't filter
      matchedVersions = @userVersions.map do |submission|
        { version: submission.version, header_position: -1, submission: }
      end
      curVersionIndex = @userVersions.index do |submission|
        submission[:version] == @submission.version
      end
    else
      matchedVersions, curVersionIndex = find_versions_with_file(@displayFilename, @userVersions,
                                                                 @submission.version)
    end

    # Previous and next versions
    @prevVersion = if curVersionIndex < (matchedVersions.size - 1)
                     matchedVersions[curVersionIndex + 1]
                   end
    @nextVersion = if curVersionIndex > 0
                     matchedVersions[curVersionIndex - 1]
                   end

    # For diff viewer
    if @prevVersion
      @prev_file_contents = get_file(@prevVersion[:submission], @prevVersion[:header_position])
    end

    # Rendering this page fails. Often. Mostly due to PDFs.
    # So if it fails, redirect, instead of showing an error page.
    if PDF.pdf?(file)
      @is_pdf = true
      @preview_mode = false
      @preview_mode = true if params[:preview]
    else
      @is_pdf = false
    end

    respond_to do |format|
      format.html { render(:view) }
      format.js
    end
  end

  action_auth_level :release_student_grade, :course_assistant
  def release_student_grade
    @submission.scores.each do |score|
      score.released = true
      score.save
    end
    redirect_back(fallback_location: root_path)
  end

  action_auth_level :unrelease_student_grade, :course_assistant
  def unrelease_student_grade
    @submission.scores.each do |score|
      score.released = false
      score.save
    end
    redirect_back(fallback_location: root_path)
  end

private

  def edit_submission_params
    params.require(:submission).permit(:notes,
                                       tweak_attributes: %i[_destroy kind value])
  end

  # Given the path to a file, return the filename to use when the user downloads it
  # path should be of the form .../<ver>_<handin> or .../annotated_<ver>_<handin>
  # returns <email>_<ver>_<handin> or annotated_<email>_<ver>_<handin>
  def download_filename(path, student_email)
    basename = File.basename path
    basename_parts = basename.split("_")
    basename_parts.insert(-3, student_email)
    basename_parts.join("_")
  end

  def get_submission_file
    unless @submission.filename
      flash[:error] = "No file associated with submission."
      redirect_to course_assessment_path(@course, @assessment) and return false
    end

    @filename = @submission.handin_file_path
    @basename = download_filename(@filename, @submission.course_user_datum.user.email)

    unless @submission.handin_annotated_file_path.nil?
      @filename_annotated = @submission.handin_annotated_file_path
      @basename_annotated = download_filename(@filename_annotated,
                                              @submission.course_user_datum.user.email)
    end

    unless File.exist? @filename
      flash[:error] = "Could not find submission file."
      redirect_to course_assessment_path(@course, @assessment) and return false
    end

    true
  end

  # Helper method to retrieve all submission versions by a student that contain a file
  def find_versions_with_file(pathname, versions, current_version)
    matchedVersions = []
    versions.each do |submission|
      submission_path = submission.handin_file_path

      # Find corresponding header position
      header_position = if Archive.archive? submission_path
                          submission_files = Archive.get_files(submission_path)
                          matched_file = submission_files.detect { |submission_file|
                            submission_file[:pathname] == pathname
                          }
                          # Skip if file doesn't exist
                          next if matched_file.nil?

                          matched_file[:header_position]
                        end
      # If not an archive, we have header_position = nil
      # This means that in _version_links.html.erb, header_position is not set in the querystring
      # for the prev / next button urls
      # This is fine since #download ignores header_position for non-archives

      # Mainly so that we don't display an asterisk next to the current version
      # On the view submission page's version dropdown
      if current_version != submission.version
        submission.header_position = header_position
      end

      matchedVersions << {
        version: submission.version,
        header_position:,
        submission:
      }
    end

    curVersionIndex = matchedVersions.index do |submission|
      submission[:version] == current_version
    end

    [matchedVersions, curVersionIndex]
  end

  def get_autograder_output(submission)
    if submission.autograde_file.nil?
      if submission.assessment.autograder.nil?
        "There is no autograding output for this submission, and no autograder is defined."
      else
        "There is no autograding output for this submission.\n" \
          "Try running the autograder by clicking the \"Run Autograder\" button above."
      end
    else
      submission.autograde_file.read || "Empty autograder output."
    end
  end

  def get_file(submission, header_position)
    handin_file_path = submission.handin_file_path

    if header_position == -1
      get_autograder_output(submission)
    elsif Archive.archive?(handin_file_path)
      file, = Archive.get_nth_file(handin_file_path, header_position.to_i)
      file
    else
      handin_file = submission.handin_file
      if handin_file.nil?
        "Could not find submission file for previous version."
      else
        handin_file.read
      end
    end
  end

  def is_binary_file?(file)
    mm = MimeMagic.by_magic(file)
    mm.present? && (!mm.text? && (mm.subtype != "pdf"))
  end

  def set_manage_submissions_breadcrumb
    return if @course.nil? || @assessment.nil? || !@cud.instructor

    @breadcrumbs << (view_context.link_to "Manage Submissions",
                                          course_assessment_submissions_path(@course, @assessment))
  end
end
