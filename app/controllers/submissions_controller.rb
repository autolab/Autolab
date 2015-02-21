class SubmissionsController < ApplicationController

  before_action :load_submission, only: [:destroy, :destroyConfirm, :download, :edit, :listArchive, :update, :view]
  before_action :get_submission_file, only: [:download, :listArchive, :view]

  # this page loads.  links/functionality may be/are off
  action_auth_level :index, :instructor
  def index
    @course = Course.where(:id => params[:course_id]).first  
    @assessment = @course.assessments.find(params[:assessment_id])
    @submissions = @assessment.submissions.order("created_at DESC")
    
    assign = @assessment.name.gsub(/\./,'')  
    modName = (assign + (@course.name).gsub(/[^A-Za-z0-9]/,"")).camelize
    @autograded = @assessment.has_autograde
  end

  # this works
  action_auth_level :new, :instructor
  def new
    @assessment = @course.assessments.find(params[:assessment_id])
    @submission = @assessment.submissions.new(tweak: Tweak.new)
    
    if params["course_user_datum_id"] != nil then
      cud_ids = params["course_user_datum_id"].split(',')
      @cuds = @course.course_user_data.find(cud_ids)
      if @cuds.size != cud_ids.size then
        @errorMessage = "Couldn't find all course_user_data in #{cuds_ids}. " +
          "Expected #{cud_ids.size} course_user_data, but only found " + 
          "#{@cuds.size} course_user_data."
        render :template=>"home/error",:status=>422 and return 
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
    @assessment = @course.assessments.find(params[:assessment_id])
    @submission = @assessment.submissions.new
    
    cud_ids = params[:submission][:course_user_datum_id].split(',')
    # Validate all users before we start
    @cuds = @course.course_user_data.find(cud_ids)
    if (@cuds.size != cud_ids.size) then 
      @errorMessage = "Invalid CourseUserDatum ID in #{cud_ids}"
      render :template=>"home/error",:status=>422 and return
    end
    for cud_id in cud_ids do 
      @submission = Submission.new(:assessment_id=>@assessment.id)
      @submission.course_user_datum_id = cud_id
      @submission.notes = params[:submission]['notes']
      if not params[:submission][:tweak_attributes][:value].blank?
        @submission.tweak = Tweak.new(params[:submission][:tweak_attributes].permit([:value, :kind, :_destroy]))
      end
      @submission.special_type = params[:submission]['special_type']
      @submission.submitted_by_id = @cud.id
      if @submission.save! then  #Now we have a version number!
        if params[:submission]['file'] &&
          (not params[:submission]['file'].blank?) then 
          @submission.saveFile(params[:submission])
        end
      end
    end
    flash[:success] = pluralize(cud_ids.size, "Submission") + " Created"
    redirect_to course_assessment_submissions_path(@course, @assessment)
  end

  action_auth_level :show, :student
  def show
    submission = Submission.find(params[:id])
    #respond_to do |format|
    #  if submission 
    #    format.js { 
    #      render :json => submission.to_json(
    #        :include => {:course_user_datum =>  # TODO: user?
    #                              {:only => [:user,
    #                                         :first_name, 
    #                                         :last_name,
    #                                         :lecture, 
    #                                         :section]}, 
    #                     :scores => {:include => :grader}}, 
    #        :methods => [:is_syntax, :is_archive, :grace_days_used,
    #                     :penalty_late_days, :days_late, :tweak],
    #        :seen_by => @cud)
    #    }
    #  else
    #    format.js { head :bad_request }
    #  end
    #end
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
    if @submission.update(edit_submission_params) then
      redirect_to history_course_assessment_path(@submission.course_user_datum.course, @assessment) and return
    else
      redirect_to edit_course_assessment_submission_path(@submission.course_user_datum.course, @assessment, @submission) and return
    end
  end

  # this is good
  action_auth_level :destroy, :instructor
  def destroy
    if params[:yes] then
      @submission.destroy!
    else
      flash[:error] = "There was an error deleting the submission."
    end
    redirect_to course_assessment_submissions_path(@submission.course_user_datum.course, @submission.assessment) and return
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
    @assessment = @course.assessments.find(params[:assessment_id])
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
    require 'tempfile'
    require 'rubygems'
    require 'zip'

    assessment = @course.assessments.find(params[:assessment_id])
    if assessment.disable_handins
      flash[:error] = "There are no submissions to download."
      redirect_to course_assessment_submissions_path(@course, assessment) and return
    end

    if params[:final]
      submissions = assessment.submissions.latest.includes(:course_user_datum)
    else
      submissions = assessment.submissions(:include => [:course_user_datum])
    end

    submissions = submissions.select { |s| @cud.can_administer?(s.course_user_datum) }
    paths = submissions.collect { |s| s.handin_file_path }
    paths = paths.select { |p| !p.nil? && File.exists?(p) && File.readable?(p) }

    if paths.nil? || paths.empty?
      flash[:error] = "There are no submissions to download."
      redirect_to(:action => "index",
                  :assessment_id => params[:assessment_id])
      return
    end

    result = Tempfile.new(['submissions', '.zip'])
    Zip::File.open(result.path, Zip::File::CREATE) do |z|
      paths.each { |p| z.add(File.basename(p), p) }
    end

    send_file(result.path, 
              :type => 'application/zip',
              :stream => false, # So we can delete the file immediately.
              :filename => File.basename(result.path))
  end

  # Action to be taken when the user wants do download a submission but
  # not actually view it. If the :header_position parameter is set, it will
  # try to send the file at that position in the archive.
  action_auth_level :download, :student
  def download
    if params[:header_position] then
      file, pathname = getFileAt params[:header_position].to_i
      if not (file and pathname) then
        flash[:error] = "Could not read archive."
        redirect_to :controller => "home", :action => "error" and return false
      end

      send_data file,
        :filename => pathname,
        :disposition => "inline"
    else
      mime = params[:forceMime] || @submission.detected_mime_type
      send_file @filename, 
        :filename => @basename,
        :disposition => "inline"
      #  :type => mime
    end
  end

  # Action to be taken when the user wants to view a particular file.
  # Tries to highlight its syntax when possible. If the :header_position
  # parameter is set, it will try to send the file at that position in
  # archive.
  action_auth_level :view, :student
  def view
    if params[:header_position] then
      file, pathname = getFileAt params[:header_position].to_i
      unless (file and pathname) then
        flash[:error] = "Could not read archive."
        redirect_to controller: :home, action: :error and return false
      end

      @displayFilename = pathname
    else
      file = @submission.handinFile.read

      @displayFilename = @submission.filename
    end
    return unless file
    
    begin
      @data = @submission.annotated_file(file, @filename, params[:header_position])
    rescue
      flash[:error] = "Sorry, we could not display your file because it contains non-ASCII characters. Please remove these characters and resubmit your work."
      redirect_to :back and return
    end

    begin
      # replace tabs with 4 spaces
      for i in 0...@data.length do
        @data[i][0].gsub!("\t", " " * 4)
      end
    rescue ArgumentError => e
      raise e unless e.message == "invalid byte sequence in UTF-8"
      flash[:error] = "Sorry, we could not parse your file because it contains non-ASCII characters. Please download file to view the source."
      redirect_to :back and return
    end

    # fix for tar files
    if params[:header_position] then
      @annotations = @submission.annotations.where(position: params[:header_position]).to_a
    else 
      @annotations = @submission.annotations.to_a
    end
    
    @annotations.sort! {|a,b| a.line <=> b.line }

    @problemSummaries = Hash.new
    @problemGrades = Hash.new
    @errorLines = ""

    # extract information from annotations
    for annotation in @annotations do
      for description, value, line, problem in annotation.get_grades do
        if problem == Annotation.PLAIN_ANNOTATION then
          next
        end
        # make the '[' swap
        description = description.gsub("\u0001", "[").gsub("\u0002", "]")
        if value == Annotation.INVALID_VALUE or 
          problem == Annotation.SYNTAX_ERROR or 
          problem == Annotation.INVALID_PROBLEM then
          if @errorLines == "" then
            @errorLines += line.to_s
          else
            @errorLines += ", #{line}"
          end
          next
        end
        if problem == Annotation.NO_PROBLEM then
          problem = "None"
        end
        @problemSummaries[problem] ||= []
        @problemSummaries[problem] << [description, value, line, annotation.submitted_by, annotation.id]

        @problemGrades[problem] ||= 0
        @problemGrades[problem] += value
      end
    end

    @problems = @assessment.problems.to_a
    @problems.sort! {|a,b| a.id <=> b.id }
    @problems.map! {|p| p.name}

    session[:problems] = @problems

    @noAnnotations = @problemSummaries.empty?
  end

  # Action to be taken when the user wants to get a listing of all
  # files in a submission that is an archive file. 
  action_auth_level :listArchive, :student
  def listArchive
    begin
      # note: @filename is defined by get_submission_file and is actually
      # submission.handin_file_path because up is down and black is white.
      archive_type = IO.popen(["file", "--brief", "--mime-type", @filename],
                              in: :close, err: :close) { |io| io.read.chomp }
      @files = []

      require 'rubygems'
      require 'rubygems/package'
      require 'zlib'
      require 'zip'

      # Extract archive by type
      if archive_type.include? "tar" then
        f = File.new(@filename)
        archive_extract = Gem::Package::TarReader.new(f)
        archive_extract.rewind # The extract has to be rewinded after every iteration
      elsif archive_type.include? "gzip" then
        archive_extract = Gem::Package::TarReader.new(Zlib::GzipReader.open @filename)
        archive_extract.rewind
      elsif archive_type.include? "zip" then
        archive_extract = Zip::File.open(@filename)
      else
        raise "Unrecognized archive type!"
      end

      # Parse archive header
      i = 0
      archive_extract.each do |entry|
        # Obtain path name depending for tar/zip entry
        pathname = entry.respond_to?(:full_name) ? entry.full_name : entry.name
        extension = File.extname pathname
        extension = extension[1..-1]
        if extension == "c0" or extension == "go" then
          extension = "c"
        elsif extension == "h0" then
          extension = "h"
        elsif extension == "clac" or extension == "sml" then
          extension = "txt"
        end
       
        next if pathname.include? "__MACOSX" or
          pathname.include? ".DS_Store" or
          pathname.include? ".metadata"

        @files << {
          :pathname => pathname,
          :header_position => i,
          :highlight => (Simplabs::Highlight.get_language_sym(extension) or (extension == "txt"))
        }

        i += 1
      end

      archive_extract.close
      return

    rescue Exception => e
        COURSE_LOGGER.log(e);
        flash[:error] = "This does not appear to be a valid archive file."
        redirect_to :controller => "home", :action => "error" and return false
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

  # Loads the submission from the DB 
  # needed by the various methods for dealing with submissions.
  # Redirects to the error page if it encounters an issue.
  def load_submission
    begin
      @assessment = @course.assessments.find params[:assessment_id]
      @submission = @assessment.submissions.find params[:id]
    rescue
      flash[:error] = "Could not find submission with id #{params[:id]}."
      redirect_to controller: :home, action: :error and return false
    end
    
    unless (@cud.instructor or @cud.course_assistant or @submission.course_user_datum_id == @cud.id) then
      flash[:error] = "You do not have permission to access this submission."
      redirect_to controller: :home, action: :error and return false
    end

    if (@assessment.exam? or @course.exam_in_progress?) and not (@cud.instructor or @cud.course_assistant) then
      flash[:error] = "You cannot view this submission.
              Either an exam is in progress or this is an exam submission."
      redirect_to controller: :home, action: :error and return false
    end
    return true
  end

  def get_submission_file
    unless @submission.filename then
      flash[:error] = "No file associated with submission."
      redirect_to controller: :home, action: :error and return false
    end

    @filename = @submission.handin_file_path
    @basename = File.basename @filename

    if not File.exists? @filename then
      flash[:error] = "Could not find submission file."
      redirect_to controller: :home, action: :error and return false
    end

    return true
  end

  # Gets the contents and path of the file at a
  # given header position in the submission archive.
  def getFileAt(position)
    require 'rubygems'
    require 'rubygems/package'
    require 'zlib'
    require 'zip'

    archive_type = IO.popen(["file", "--brief", "--mime-type", @filename],
                            in: :close, err: :close) { |io| io.read.chomp }
    # Extract archive by type
    if archive_type.include? "tar" then
      f = File.new(@filename)
      archive_extract = Gem::Package::TarReader.new(f)
      archive_extract.rewind # The extract has to be rewinded after every iteration
    elsif archive_type.include? "gzip" then
      archive_extract = Gem::Package::TarReader.new(Zlib::GzipReader.open @filename)
      archive_extract.rewind
    elsif archive_type.include? "zip" then
      archive_extract = Zip::File.open(@filename)
    else
      raise "Unrecognized archive type!"
    end

    # Iterate through archive until file position
    i = 0
    archive_extract.each do |entry|
      # Obtain path name depending for tar/zip entry
      pathname = entry.respond_to?(:full_name) ? entry.full_name : entry.name
      # Skip Mac metafiles
      next if pathname.include? "__MACOSX" or
          pathname.include? ".DS_Store" or
          pathname.include? ".metadata"

      if i == position then
        return nil, nil unless entry
        # Case One: tar or tgz archive
        if entry.respond_to?(:read) then
          return entry.read, entry.full_name
        # Case Two: zip archive
        else
          return entry.get_input_stream.read, entry.name
        end
      end

      i += 1
    end

    return nil, nil unless header
  end

  # Extract the andrewID from a filename.
  # Filename format is andrewID_version_asessment.ext
  def extractAndrewID(filename)
    underscoreInd = filename.index("_")
    if !underscoreInd.nil?  
      return filename[0...underscoreInd]
    end
    return nil 
  end

  # Extract the version from a filename
  # Filename format is andrewID_version_asessment.ext
  def extractVersion(filename)
    firstUnderscoreInd = filename.index("_")
    return nil unless !firstUnderscoreInd.nil? 

    secondUnderscoreInd = filename.index("_", firstUnderscoreInd + 1)
    return nil unless !secondUnderscoreInd.nil?
    return filename[firstUnderscoreInd + 1...secondUnderscoreInd].to_i
  end

end
