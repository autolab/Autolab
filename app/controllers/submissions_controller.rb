require "archive"
require "pdf"
require "prawn"

class SubmissionsController < ApplicationController
  # inherited from ApplicationController
  before_action :set_assessment
  before_action :set_submission, only: [:destroy, :destroyConfirm, :download, :edit, :listArchive, :update, :view]
  before_action :get_submission_file, only: [:download, :listArchive, :view]
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
      @submission.destroy!
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

    result = Archive.create_zip paths

    if result.nil?
      flash[:error] = "There are no submissions to download."
      redirect_to([@course, @assessment, :submissions]) && return
    end

    send_file(result.path,
              type: "application/zip",
              stream: false, # So we can delete the file immediately.
              filename: File.basename(result.path)) && return
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

      @annotations = @submission.annotations.to_a

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

          comment = "#{annotation.comment}\n\nProblem: #{problem_name}\nScore:#{value}"

          pdf.stroke_color "ff0000"
          pdf.stroke_rectangle [xCord, yCord], width, height
          pdf.fill_color "000000"

          # + 1 since pages are indexed 1-based
          pdf.go_to_page(page + 1)
          pdf.fill_color "ff0000" 
          pdf.text_box comment,
                      { :at => [xCord + 3, yCord - 3], 
                        :height => height, 
                        :width => width }

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
    if params[:header_position]
      file, pathname = Archive.get_nth_file(@submission.handin_file_path, params[:header_position].to_i)
      unless file && pathname
        flash[:error] = "Could not read archive."
        redirect_to [@course, @assessment] and return false
      end

      @displayFilename = pathname
      @breadcrumbs << (view_context.link_to "View Archive", [:list_archive, @course, @assessment, @submission])
    else
      # redirect on archives
      redirect_to(action: :listArchive) && return if Archive.archive?(@submission.handin_file_path)

      file = @submission.handin_file.read

      @displayFilename = @submission.filename
    end
    return unless file

    filename = @submission.handin_file_path


    if !PDF.pdf?(file)
      begin
        @data = @submission.annotated_file(file, @filename, params[:header_position])
      rescue
        flash[:error] = "Sorry, we could not display your file because it contains non-ASCII characters. Please remove these characters and resubmit your work."
        redirect_to(:back) && return
      end

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

      # fix for tar files
      if params[:header_position]
        @annotations = @submission.annotations.where(position: params[:header_position]).to_a
      else
        @annotations = @submission.annotations.to_a
      end

      @annotations.sort! { |a, b| a.line <=> b.line }

    else
      # fix for tar files
      if params[:header_position]
        @annotations = @submission.annotations.where(position: params[:header_position]).to_a
      else
        @annotations = @submission.annotations.to_a
      end

    end

    @problemSummaries = {}
    @problemGrades = {}


    @annotations.delete_if do |annotation|
      problem = annotation.problem ? annotation.problem.name : "General"
      if problem != "General" then
        out = Score.where("submission_id = ? AND  problem_id = ?", @submission.id, Problem.where("assessment_id = ? AND name = ?", @assessment.id, problem).first.id).first.released
        if out || (@cud.instructor || @cud.course_assistant) then
          false
        else
          if(@assessment.grading_deadline.past?) then 
            false
          else
            true
          end
        end
      else
        if(@assessment.grading_deadline.past? || (@cud.instructor || @cud.course_assistant)) then 
          false
        else
          true
        end
      end 
    end
    # extract information from annotations
    @annotations.each do |annotation|
      description = annotation.comment
      value = annotation.value || 0
      line = annotation.line
      problem = annotation.problem ? annotation.problem.name : "General"


      @problemSummaries[problem] ||= []
      @problemSummaries[problem] << [description, value, line, annotation.submitted_by, annotation.id]

      @problemGrades[problem] ||= 0
      @problemGrades[problem] += value
    end


    @problems = @assessment.problems.to_a
    @problems.sort! { |a, b| a.id <=> b.id }

    # Rendering this page fails. Often. Mostly due to PDFs.
    # So if it fails, redirect, instead of showing an error page.
    if PDF.pdf?(file)
      @preview_mode = false
      if params[:preview] then 
        @preview_mode = true 
      end

      render(:viewPDF) && return
    else 
      begin
        render(:view) && return
      rescue
        flash[:error] = "Autolab cannot display this file"
        if params[:header_position]
          redirect_to([:list_archive, @course, @assessment, @submission]) && return
        else
          redirect_to([:history, @course, @assessment, cud_id: @submission.course_user_datum_id]) && return
        end
      end
    end
  end

  # Action to be taken when the user wants to get a listing of all
  # files in a submission that is an archive file.
  action_auth_level :listArchive, :student
  def listArchive
    @files = Archive.get_files(@filename).sort! { |a, b| a[:pathname] <=> b[:pathname] }
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
