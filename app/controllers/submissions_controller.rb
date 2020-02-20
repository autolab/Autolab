require "archive"
require "pdf"
require "prawn"
require "json"
require 'tempfile'

class SubmissionsController < ApplicationController
  # inherited from ApplicationController
  before_action :set_assessment
  before_action :set_submission, only: [:destroy, :destroyConfirm, :download, :edit, :update, :view]
  before_action :get_submission_file, only: [:download, :view]
  rescue_from ActionView::MissingTemplate do |exception|
      redirect_to("/home/error_404")
  end

  # this page loads.  links/functionality may be/are off
  action_auth_level :index, :instructor
  def index
    @submissions = @assessment.submissions.order("created_at DESC")

    assign = @assessment.name.gsub(/\./, "")
    modName = (assign + (@course.name).gsub(/[^A-Za-z0-9]/, "")).camelize
    @autograded = @assessment.has_autograder?
  end

  # this works
  action_auth_level :new, :instructor
  def new
    @submission = @assessment.submissions.new(tweak: Tweak.new)

    if !params["course_user_datum_id"].nil?
      cud_ids = params["course_user_datum_id"].split(",")
      @cuds = @course.course_user_data.find(cud_ids)
      if @cuds.size != cud_ids.size
        @errorMessage = "Couldn't find all course_user_data in #{cuds_ids}. " \
          "Expected #{cud_ids.size} course_user_data, but only found " \
          "#{@cuds.size} course_user_data."
        render([@course, @assessment, :submissions]) && return
      end
    else
      @cuds = {}
      # TODO: change order
      for cud in @course.course_user_data.joins(:user).order("email ASC") do
        @cuds[cud.full_name_with_email] = cud.id
      end
    end
  end

  # this seems to work to.
  action_auth_level :create, :instructor
  def create
    @submission = @assessment.submissions.new

    cud_ids = params[:submission][:course_user_datum_id].split(",")
    # Validate all users before we start
    @cuds = @course.course_user_data.find(cud_ids)
    if (@cuds.size != cud_ids.size)
      @errorMessage = "Invalid CourseUserDatum ID in #{cud_ids}"
      render([@course, @assessment, :submissions]) && return
    end
    for cud_id in cud_ids do
      @submission = Submission.new(assessment_id: @assessment.id)
      @submission.course_user_datum_id = cud_id
      @submission.notes = params[:submission]["notes"]
      unless params[:submission][:tweak_attributes][:value].blank?
        @submission.tweak = Tweak.new(params[:submission][:tweak_attributes].permit([:value, :kind, :_destroy]))
      end
      @submission.special_type = params[:submission]["special_type"]
      @submission.submitted_by_id = @cud.id
      if @submission.save!  # Now we have a version number!
        if params[:submission]["file"] &&
           (!params[:submission]["file"].blank?)
          @submission.save_file(params[:submission])
        end
      end
    end
    flash[:success] = pluralize(cud_ids.size, "Submission") + " Created"
    redirect_to course_assessment_submissions_path(@course, @assessment)
  end

  action_auth_level :show, :student
  def show
    submission = Submission.find(params[:id])
  end

  # this loads and looks good
  action_auth_level :edit, :instructor
  def edit
    @submission.tweak ||= Tweak.new
  end

  # this is good
  action_auth_level :update, :instructor
  def update
    if @submission.nil?
      flash[:error] = "Cannot update nil submission"
    end

    if params[:submission][:tweak_attributes][:value].blank?
      params[:submission][:tweak_attributes][:_destroy] = true
    end
    if @submission.update(edit_submission_params)
      redirect_to(history_course_assessment_path(@submission.course_user_datum.course, @assessment)) && return
    else
      redirect_to(edit_course_assessment_submission_path(@submission.course_user_datum.course, @assessment, @submission)) && return
    end
  end

  # this is good
  action_auth_level :destroy, :instructor
  def destroy
    if params[:yes]
      if @submission.destroy
        flash[:success] = "Submission successfully destroyed"
      else
        flash[:error] = "Submission failed to be destroyed"
      end
    else
      flash[:error] = "There was an error deleting the submission."
    end
    redirect_to(course_assessment_submissions_path(@submission.course_user_datum.course, @submission.assessment)) && return
  end

  # this is good
  action_auth_level :destroyConfirm, :instructor
  def destroyConfirm
  end

  ##
  ## THIS MARKS THE END OF RESTful ROUTES
  ##

  # TODONE?  THIS MAY DELETE MOST OF YOUR USERS.  USE WITH CAUTION.
  action_auth_level :missing, :instructor
  def missing
    @submissions = @assessment.submissions

    cuds = @course.students.to_a
    @missing = []

    for submission in @submissions do
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
    if @assessment.nil?
      flash[:error] = "Cannot index submissions for nil assessment"
    end

    if !@assessment.valid?
      @assessment.errors.full_messages.each do |msg|
        flash[:error] += "<br>#{msg}"
      end
    end

    if @assessment.disable_handins
      flash[:error] = "There are no submissions to download."
      redirect_to([@course, @assessment, :submissions]) && return
    end

    if params[:final]
      submissions = @assessment.submissions.latest.includes(:course_user_datum)
    else
      submissions = @assessment.submissions.includes(:course_user_datum)
    end

    submissions = submissions.select { |s| @cud.can_administer?(s.course_user_datum) }
    paths = submissions.collect(&:handin_file_path)
    paths = paths.select { |p| !p.nil? && File.exist?(p) && File.readable?(p) }

    result = Archive.create_zip paths # result is stringIO to be sent

    if result.nil?
      flash[:error] = "There are no submissions to download."
      redirect_to([@course, @assessment, :submissions]) && return
    end

    send_data(result.read, # to read from stringIO object returned by create_zip
              type: "application/zip",
              disposition: "attachment", # tell browser to download
              filename: "#{@course.name}_#{@course.semester}_#{@assessment.name}_submissions.zip") && return
  end

  # Action to be taken when the user wants do download a submission but
  # not actually view it. If the :header_position parameter is set, it will
  # try to send the file at that position in the archive.
  action_auth_level :download, :student
  def download
    if params[:header_position]
      file, pathname = Archive.get_nth_file(@filename, params[:header_position].to_i)
      unless file && pathname
        flash[:error] = "Could not read archive."
        redirect_to [@course, @assessment] and return false
      end

      send_data file,
                filename: pathname,
                disposition: "inline"

    elsif params[:annotated]

      @filename_annotated = @submission.handin_annotated_file_path
      @basename_annotated = File.basename @filename_annotated

      @problems = @assessment.problems.to_a
      @problems.sort! { |a, b| a.id <=> b.id }

      # Only show annotations if grades have been released or the user is an instructor
      @annotations = []
      if(!@assessment.before_grading_deadline? || @cud.instructor || @cud.course_assistant)
        @annotations = @submission.annotations.to_a
      end

      Prawn::Document.generate(@filename_annotated, :template => @filename) do |pdf|

        @annotations.each do |annotation|

          return if annotation.coordinate.nil?

          position = annotation.coordinate.split(',')
          page  = position[2].to_i

          width = position[3].to_f * pdf.bounds.width
          height = position[4].to_f * pdf.bounds.height

          xCord = position[0].to_f * pdf.bounds.width
          yCord = pdf.bounds.height - (position[1].to_f * pdf.bounds.height)

          value = "N/A"
          if !annotation.value.blank? then value = annotation.value end

          if annotation.problem then problem = annotation.problem end
          problem_name = "General"
          if !problem.nil? then problem_name = problem.name end

          comment = "#{annotation.comment}\n\nProblem: #{problem_name}\nScore: #{value}"

          # + 1 since pages are indexed 1-based
          pdf.go_to_page(page + 1)
          
          # Creates a text annotation/pdf comment on the pdf itself.
          # 10 and 55 numbers in this case to shift the comment
          # to where the cursor was clicked by the annotator
          ary = [xCord + 10,yCord + 55, width, height]
          pdf.text_annotation(ary,comment)

        end

      end

      send_file @filename_annotated,
                filename: @basename_annotated,
                disposition: "inline"

    else
      mime = params[:forceMime] || @submission.detected_mime_type

      send_file @filename,
                filename: @basename,
                disposition: "inline"
      #  :type => mime
    end
  end

  # Action to be taken when the user wants to view a particular file.
  # Tries to highlight its syntax when possible. If the :header_position
  # parameter is set, it will try to send the file at that position in
  # archive.
  action_auth_level :view, :student
  def view
    if(@course.nil?)
      flash[:error] = "Cannot manage nil course"
    end

    # Pull the files with their hierarchy info for the file tree
    if Archive.archive? @filename
      @files = Archive.get_file_hierarchy(@filename).sort! { |a, b| a[:pathname] <=> b[:pathname] }
      @header_position = params[:header_position].to_i
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

    if params[:header_position]
      file, pathname = Archive.get_nth_file(@submission.handin_file_path, params[:header_position].to_i)

      if(file.nil?)
        file = ""
      end

      unless file && pathname
        flash[:error] = "Could not read archive."
        redirect_to [@course, @assessment] and return false
      end

      @displayFilename = pathname
    else
      # auto-set header position for archives
      if Archive.archive?(@submission.handin_file_path)
        firstFile = Archive.get_files(@submission.handin_file_path).find{|file| file[:mac_bs_file] == false and file[:directory] == false} || {header_position: 0}
        redirect_to(url_for([:view, @course, @assessment, @submission, header_position: firstFile[:header_position]])) && return
      end

      file = @submission.handin_file.read

      @displayFilename = @submission.filename
    end
    return unless file

    if !PDF.pdf?(file)
      # begin
        @data = @submission.annotated_file(file, @filename, params[:header_position])
        # Try extracting a symbol tree
        begin
          codePath = @filename
          if Archive.archive?(@submission.handin_file_path)
            # If the submission is an archive, write the open file's code to a temp file so we can pass it into ctags
            ctagFile = Tempfile.new(['autolab_ctag', File.extname(pathname)])
            ctagFile.write(file)
            ctagFile.close
            codePath = ctagFile.path
          end
          # Special case -- we're using a CMU-specific language, and we need to
          # force the language interpretation
          if(codePath.last(3) == ".c0" or codePath.last(3) == ".c1")
            @ctags_json = %x[ctags --output-format=json --language-force=C --fields="Nnk" #{codePath}].split("\n")
          else
            # General case -- language can be inferred from file extension
            @ctags_json = %x[ctags --extras=+q --output-format=json --fields="Nnk" #{codePath}].split("\n")
          end

          @ctag_obj = []
          i = 0
          while i < @ctags_json.length
            obj_temp = JSON.parse(@ctags_json[i])
            if(obj_temp["kind"] == "function" or obj_temp["kind"] == "method")
              # check that obj_temp does not exist in array
              if ((@ctag_obj.select{|ctag| ctag["line"] == obj_temp["line"] }).empty?)
                @ctag_obj.push(obj_temp)
              end
            end
            i = i + 1

            if(obj_temp["kind"] == "class")
              obj_temp = JSON.parse(@ctags_json[i])
              while i + 1 < @ctags_json.length and (obj_temp["kind"] == "member" or obj_temp["kind"] == "method")
                obj_exists = @ctag_obj.select{|ctag| ctag["line"] == obj_temp["line"]}
                if (obj_exists.empty?)
                  @ctag_obj.push(obj_temp)
                # we want the obj with the extra class-qualified tag entry, 'class.function'
                elsif (obj_temp["name"].length > obj_exists[0]["name"].length)
                  @ctag_obj[@ctag_obj.index(obj_exists[0])] = obj_temp
                end
                i = i + 1
                obj_temp = JSON.parse(@ctags_json[i])
              end
            end
          end

          # The functions are in some arbitrary order, so sort them
          @ctag_obj = @ctag_obj.sort_by { |obj| obj["line"].to_i }

        rescue
          puts("Ctags not installed or failed")
        ensure
          if defined?(ctagFile) && !ctagFile.nil?
            ctagFile.unlink
          end
        end
      # rescue
        # flash[:error] = "Sorry, we could not display your file because it contains non-ASCII characters. Please remove these characters and resubmit your work."
        # redirect_to(:back) && return
      # end

      begin
        # replace tabs with 4 spaces
        for i in 0...@data.length do
          @data[i][0].gsub!("\t", " " * 4)
        end
      rescue ArgumentError => e
        raise e unless e.message == "invalid byte sequence in UTF-8"
        flash[:error] = "Sorry, we could not parse your file because it contains non-ASCII characters. Please download file to view the source."
        redirect_to(:back) && return
      end
    end

    @problemReleased = @submission.scores.pluck(:released).all?

    @annotations = @submission.annotations.to_a
    @annotations.sort! { |a, b| a.line.to_i <=> b.line.to_i }

    @problemSummaries = {}
    @problemGrades = {}


    # Only show annotations if grades have been released or the user is an instructor
    unless(!@assessment.before_grading_deadline? || @cud.instructor || @cud.course_assistant)
      @annotations = []
    end

    # extract information from annotations
    @annotations.each do |annotation|
      description = annotation.comment
      value = annotation.value || 0
      line = annotation.line
      problem = annotation.problem ? annotation.problem.name : "General"

      @problemSummaries[problem] ||= []
      @problemSummaries[problem] << [description, value, line, annotation.submitted_by, annotation.id, annotation.position]

      @problemGrades[problem] ||= 0
      @problemGrades[problem] += value

    end


    @problems = @assessment.problems.to_a
    @problems.sort! { |a, b| a.id <=> b.id }

    @latestSubmissions = @assessment.assessment_user_data
                          .map{|aud| aud.latest_submission}
                          .select{|submission| submission != nil}
                          .sort_by{|submission| submission.course_user_datum.user.email}
    @curSubmissionIndex = @latestSubmissions.index{|submission| submission.course_user_datum.user.email == @submission.course_user_datum.user.email}
    @prevSubmission = @curSubmissionIndex > 0 ? @latestSubmissions[@curSubmissionIndex-1] : nil
    @nextSubmission = @curSubmissionIndex < (@latestSubmissions.size-1) ? @latestSubmissions[@curSubmissionIndex+1] : nil

    # Adding allowing scores to be assessed by the view
    @scores = Score.where(submission_id: @submission.id)
    
    # Rendering this page fails. Often. Mostly due to PDFs.
    # So if it fails, redirect, instead of showing an error page.
    if PDF.pdf?(file)
      @is_pdf = true
      @preview_mode = false
      if params[:preview] then
        @preview_mode = true
      end
    else
      @is_pdf = false
    end

    respond_to do |format|
      format.html { render(:view) }
      format.js
    end
  end

private

  def new_submission_params
    params.require(:submission).permit(:course_used_datum_id, :notes, :file,
                                       tweak_attributes: [:_destroy, :kind, :value])
  end

  def edit_submission_params
    params.require(:submission).permit(:notes,
                                       tweak_attributes: [:_destroy, :kind, :value])
  end

  def get_submission_file
    unless @submission.filename
      flash[:error] = "No file associated with submission."
      redirect_to [@course, @assessment] and return false
    end

    @filename = @submission.handin_file_path
    @basename = File.basename @filename

    basename_parts = @basename.split("_")
    basename_parts.insert(-3, @assessment.name)

    @basename = basename_parts.join("_")

    unless File.exist? @filename
      flash[:error] = "Could not find submission file."
      redirect_to [@course, @assessment] and return false
    end

    true
  end

  # Extract the andrewID from a filename.
  # Filename format is andrewID_version_asessment.ext
  def extractAndrewID(filename)
    underscoreInd = filename.index("_")
    return filename[0...underscoreInd] unless underscoreInd.nil?
    nil
  end

  # Extract the version from a filename
  # Filename format is andrewID_version_asessment.ext
  def extractVersion(filename)
    firstUnderscoreInd = filename.index("_")
    return nil if firstUnderscoreInd.nil?

    secondUnderscoreInd = filename.index("_", firstUnderscoreInd + 1)
    return nil if secondUnderscoreInd.nil?
    filename[firstUnderscoreInd + 1...secondUnderscoreInd].to_i
  end
end
