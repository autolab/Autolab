class SubmissionsController < ApplicationController

  autolabRequire File.join(Rails.root, 'app/controllers/assessment/autograde.rb')
  include AssessmentAutograde

  before_action :load_submission, only: [:destroy]

  # this page loads.  links/functionality may be/are off
  action_auth_level :index, :instructor
  def index
    @course = Course.where(:id => params[:course_id]).first  
    @assessment = @course.assessments.find(params[:assessment_id])
    @submissions = @assessment.submissions.order("created_at DESC")
    
    assign = @assessment.name.gsub(/\./,'')  
    modName = (assign + (@course.name).gsub(/[^A-Za-z0-9]/,"")).camelize
    @autograded = false
    begin
      @autograded = @assessment.has_autograde
    rescue Exception 
    end
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

  # method called when Tango returns the output
  # action_auth_level :autograde_done, :student
  action_no_auth :autograde_done
  def autograde_done
    
    feedback_str = params[:file].read

    @submission = Submission.where(id: params[:id], dave: params[:dave]).first
    @course = Course.where(id: params[:course_id]).first
    @assessment = Assessment.where(id: params[:assessment_id]).first

    COURSE_LOGGER.setCourse(@course)
    COURSE_LOGGER.log("autograde_done")
    COURSE_LOGGER.log("autograde_done hit: #{request.fullpath}")

    unless @submission and @course and @assessment then
      render nothing: true and return
    end

    autolab_dir = File.expand_path(File.dirname(__FILE__)+'/../../')
    configName = "#{@course.name}-#{@assessment.name}.rb"
    dir = File.join(autolab_dir, "assessmentConfig", configName)
    require_relative dir

    assign = @assessment.name.gsub(/\./,'') 
    modName = (assign + (@course.name).gsub(/[^A-Za-z0-9]/,"")).camelize

    if @assessment.has_autograde then
      
      if @assessment.overwrites_method?(:autogradeDone) then
        @assessment.config_module.autogradeDone(@submission, feedback_str)
      else
        autogradeDone(@submission, feedback_str)
      end

    end

    render :nothing => true
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
    load_submission() or return false
    @submission.tweak ||= Tweak.new
  end

  # this is good
  action_auth_level :update, :instructor
  def update
    load_submission() or (redirect_to history_course_assessment_path(@submission.course_user_datum.course, @assessment) and return false)
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
    if params[:yes] && load_submission() then
      @submission.destroy!
    else
      flash[:error] = "There was an error deleting the submission."
    end
    redirect_to course_assessment_submissions_path(@submission.course_user_datum.course, @submission.assessment) and return
  end

  # this is good
  action_auth_level :destroyConfirm, :instructor
  def destroyConfirm
    load_submission() or return false
  end

  action_auth_level :regrade, :instructor
  def regrade
    @submission = Submission.find(params[:id])
    @effectiveCud = @submission.course_user_datum
    @course = @submission.course_user_datum.course
    @assessment = @submission.assessment

    if !@assessment.has_autograde then
      # Not an error, this behavior was specified!
      flash[:info] = "This submission is not autogradable"
      redirect_to :action=>"history", :id=>@effectiveCud.id and return -3
    end

    jobid = sendJob()

    if jobid == -2 then 
      link = "<a href=\"#{url_for(:action=>'adminAutograde')}\">Admin Autograding</a>"
      flash[:error] = "Autograding failed because there are no autograding properties. " +
        " Visit #{link} to set the autograding properties."
    elsif jobid == -1 then 
      link = "<a href=\"#{url_for(:controller=>'jobs')}\">Jobs</a>"
      flash[:error] = "There was an error submitting your autograding job. " +
        "Check the #{link} page for more info."
    else
      link = "<a href=\"#{url_for(:controller=>'jobs')}\">Job ID = #{jobid}</a>"
      flash[:success] = ("Success: Regrading #{@submission.filename} (#{link})").html_safe
    end
    
    redirect_to history_course_assessment_path(@course, @assessment, cud_id: @effectiveCud.id) and return
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

  # 
  # regradeAll - regrade the most recent submissions from each student
  #
  action_auth_level :regradeAll, :instructor
  def regradeAll
    # load_submission() or return false
    @assessment = Assessment.where(:id => params[:assessment_id]).first

    # Grab all of the submissions for this assessment
    @submissions = Submission.where(:assessment_id=>@assessment.id,
                                    :special_type=>Submission::NORMAL).order("version DESC")

    last_submissions = @submissions.latest

    # Now regrade only the most recent submissions. Keep track of
    # any handins that fail.
    failed_jobs = 0
    failed_list = ""
    for @submission in last_submissions do
      if autograde?(@submission) then
        job = sendJob()
        if job == -1 then
          failed_jobs += 1
          failed_list += "#{@submission.filename}: autograding error.<br>"
        elsif job == -2 then
          link = "<a href=\"#{url_for(:action=>'adminAutograde')}\">Admin Autograding</a>"
          flash[:error] = "No jobs autograded because there are no autograding properties." +
            " Visit #{link} to set the autograding properties."
          redirect_to(:controller=>"submission", 
                      :action=>"index", 
                      :assessment_id=>@assessment.id) and return
        end
      else
        failed_jobs += 1
        failed_list += "#{@submission.filename}: not found or not readable.<br>"
      end
    end

    if failed_jobs > 0 then
      flash[:error] = "Warning: Could not regrade #{failed_jobs} submission(s):<br>" + failed_list
    end
    success_jobs = last_submissions.size - failed_jobs
    if success_jobs > 0 then
      link = "<a href=\"#{url_for(:controller=>'jobs')}\">#{success_jobs} students</a>"
      flash[:success] = ("Regrading the most recent submissions from #{link}").html_safe
    end

    redirect_to :controller=>"submissions", :action=>"index", :assessment_id=>@assessment.id and return
  end

  # Action to be taken when the user wants do download a submission but
  # not actually view it. If the :header_position parameter is set, it will
  # try to send the file at that position in the archive.
  action_auth_level :download, :student
  def download
    load_submission() or return false
    get_submission_file() or return false
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
    load_submission() or return false
    get_submission_file() or return false

    @course = @submission.course_user_datum.course

    if params[:header_position] then
      file, pathname = getFileAt params[:header_position].to_i
      if not (file and pathname) then
        flash[:error] = "Could not read archive."
        redirect_to :controller => "home", :action => "error" and return false
      end

      @displayFilename = pathname

      extension = File.extname pathname
      extension = extension[1..-1]
    else
      extension = File.extname @submission.filename
      extension = extension[1..-1]
      file = @submission.handinFile.read

      @displayFilename = @submission.filename
    end
    return unless file
    
    if extension == "c0" or extension == "go" then
      extension = "c"
    elsif extension == "h0" then
      extension = "h"
    elsif extension == "clac" or extension == "sml" then
      extension = "txt"
    end
    
    @escape_code = false
    if extension and Simplabs::Highlight.get_language_sym extension then
      begin
        file = Simplabs::Highlight.highlight extension, file
        @data = @submission.annotated_file(file, @filename, params[:header_position])
      rescue
        flash[:error] = "Could not display file because it's extension isn't supported."
      end
    elsif extension and extension == "txt" then
      @escape_code = true
      begin
        @data = @submission.annotated_file(file, @filename, params[:header_position])
      rescue
        flash[:error] = "Could not display file"
      end
    end

    if @data.nil? || @data.empty? then
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
      annotations = Annotation.where("submission_id = ? and position = ?", @submission.id, params[:header_position]).to_a
    else 
      annotations = Annotation.where("submission_id = ?", @submission.id).to_a
    end
    
    annotations.sort! {|a,b| a.line <=> b.line }

    @problemSummaries = Hash.new
    @problemGrades = Hash.new
    @errorLines = ""

    # extract information from annotations
    for annotation in annotations do
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

    @problems = Problem.where("assessment_id = ?", @submission.assessment_id).to_a
    @problems.sort! {|a,b| a.id <=> b.id }
    @problems.map! {|p| p.name}

    session[:problems] = @problems

    @noAnnotations = @problemSummaries.empty?
  end

  # Action to be taken when the user wants to get a listing of all
  # files in a submission that is an archive file. 
  def listArchive
    begin
      load_submission() or return false
      get_submission_file() or return false

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



  # AUTOGRADING
  #
  # autogradeDone - called when autograding is done, either by the submissions#autograde_done
  # route getting called by Tango or by the Autograde module polling Tango. In either case,
  # submission is confirmed via dave key to have been created by Autolab
  #
  def autogradeDone(submission, feedback)
    @user = submission.course_user_datum.user

    assessmentDir = File.join(AUTOCONFIG_COURSE_DIR, submission.course_user_datum.course.name, submission.assessment.name)

    filename = @submission.course_user_datum.email + "_" + 
      @submission.version.to_s + "_" +
      @assessment.name + "_" +
      "autograde.txt"

    feedbackFile = File.join(assessmentDir, @assessment.handin_directory, filename)
    COURSE_LOGGER.log("Looking for Feedbackfile:" + feedbackFile)

    submission = Submission.find(submission)

    begin
      f = File.open(feedbackFile, "w")
      f.write(feedback)
    ensure
      f.close unless f.nil?
    end
    
    saveAutograde(submission,feedbackFile)
  end

  #
  # saveAutograde - parses the autoresult returned by the
  # autograding driver on the backend and updates the scores for
  # each autograded problem. The default autoresult string is in
  # JSON format, but this can be overrriden in the lab.rb file.
  #
  def saveAutograde(submission,feedbackFile)
    lines = File.open(feedbackFile).readlines()
    begin
      
      if @assessment.has_partners then
        # Create a submission for partner
        pSubmission = createPartnerSubmission(submission)
      end
      
      if (lines == nil) then
        raise "The Autograder returned no output. \n"
      end

      # The last line of the output is assumed to be the
      # autoresult string from the autograding driver
      autoresult = lines[lines.length-1].chomp

      if @assessment.overwrites_method?(:parseAutoresult) then
        scores = @assessment.config_module.parseAutoresult(autoresult, true);
      else
        scores = parseAutoresult(autoresult, true)
      end

      if scores.keys.length == 0 then 
        raise "Empty autoresult string."
      end

      # Grab the autograde config info
      @autograde_prop = AutogradingSetup.where(:assessment_id => @assessment.id).first

      # Record each of the scores extracted from the autoresult
      for key in scores.keys do
        problem = @assessment.problems.where(:name => key).first
        if !problem then
          raise "Problem \"" + key + "\" not found."
        end
        score = submission.scores.where(:problem_id => problem.id).first
        if !score then 
          score = submission.scores.new(:problem_id=>problem.id)
        else
          score = submission.scores.where(:problem_id => problem.id).first
        end
        score.score = scores[key]
        score.feedback = lines.join()
        score.released = @autograde_prop.release_score
        score.grader_id = 0
        puts "save score"
        puts score.save!
       
      	if @assessment.has_partners then 
          # call method in ModuleBase to update this score for partner
          saveAutogradeForPartner(score, pSubmission)
      	end

      end
    rescue Exception => e
      feedback_str = "An error occurred while parsing the autoresult returned by the Autograder.\n\nError message: " + e.to_s + "\n\n"
      if lines && (lines.length < 10000) then
        feedback_str += lines.join()
      end
      @assessment.problems.each do |p|
        score = submission.scores.find_or_initialize_by(problem_id: p.id)
        score.score = 0
        score.feedback = feedback_str

        score.released = true
        score.grader_id = 0
        score.save!

        if @assessment.has_partners then
          # call method in ModuleBase to update this score for parter
          saveAutogradeForPartner(score, pSubmission)
        end
      end
    end

    submission.autoresult = autoresult
    submission.save
    # save autoresult for partner
    if pSubmission then
      pSubmission.autoresult = autoresult
      pSubmission.save
    end
    logger = Logger.new(Rails.root.join("courses", @course.name, @assessment.name, "log.txt"))
    logger.add(Logger::INFO) {"#{submission.course_user_datum.email}, #{submission.version}, #{autoresult}"}
  end

  # 
  # parseAutoresult - Extracts the problem scores from a JSON
  # autoresult string. If anything goes wrong, raise an exception
  # with the caller. Can be overridden in the lab config file.
  #
  def parseAutoresult(autoresult, isOfficial)
    parsed = ActiveSupport::JSON.decode(autoresult.gsub(/([a-zA-Z0-9]+):/, '"\1":'))
    if !parsed then
      raise "Empty autoresult"
    end
    if !parsed["scores"] then
      raise "Missing 'scores' object in the autoresult"
    end
    return parsed["scores"]
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
      @submission = Submission.find params[:id]
    rescue
      flash[:error] = "Could not find submission with id #{params[:id]}."
      redirect_to :controller => "home", :action => "error" and return false
      return false
    end
    
    if not (@submission.course_user_datum.user == @cud.user or
      @cud.instructor? or @cud.user.administrator? or
      @cud.course_assistant?) then
      flash[:error] = "You do not have permission to access this submission."
      redirect_to :controller => "home", :action => "error" and return false
    end

    @assessment = @submission.assessment

    if ((!@cud.user.administrator?) && (@cud.course_id != @assessment.course_id)) then 
      flash[:error] = "You do not have permission to access this submission"
      redirect_to :controller=>"home" , :action=>"error" and return false
    end

    if (@assessment.exam? or @submission.course_user_datum.course.exam_in_progress?) and
        not (@cud.instructor? or @cud.course_assistant? or @cud.user.administrator?)
      flash[:error] = "You cannot view this submission.
              Either an exam is in progress or this is an exam submission."
          redirect_to :controller=>"home", :action=>"error" and return false
    end
    return true
  end

  action_auth_level :get_submission_file, :student
  def get_submission_file
    if not @submission.filename then
      flash[:error] = "No file associated with submission."
      redirect_to :controller => "home", :action => "error" and return false
      return false
    end

    @filename = @submission.handin_file_path
    @basename = File.basename @filename

    if not File.exists? @filename then
      flash[:error] = "Could not find submission file."
      redirect_to :controller => "home", :action => "error" and return false
      return false
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

  def extend_config_module
    begin
      @assessment = @submission.assessment
      require @assessment.config_file_path
            

      # casted to local variable so that 
      # they can be passed into `module_eval`
      assessment = @assessment
      methods = @assessment.config_module.instance_methods
      assignName = @assessment.name
      submission = @submission

      course = @course
      cud = @cud
      req_hostname = request.host;
      req_port = request.port;

      @assessment.config_module.module_eval do
        
        # we cast these values into module variables
        # so that they can be accessible inside module
        # methods
        @cud = cud
        @course = course
        @assessment = course.assessments.where(:name=>assignName).first
        @hostname = req_hostname
        @port = req_port
        @submission = submission

        if ! @assessment then
          raise "Assessment #{assignName} does not exist!"
        end

        if @assessment == nil then
          flash[:error] = "Error: Invalid assessment"
          redirect_to home_error_path and return
        end

        @name = @assessment.name
        @description = @assessment.description
        @start_at = @assessment.start_at
        @due_at = @assessment.due_at
        @end_at = @assessment.end_at
        @visible_at = @assessment.visible_at
        @id = @assessment.id

        # we iterate over all the methods
        # and convert them into `module methods`
        # this makes them available without mixing in the module
        # creating an instance of it.
        # http://www.ruby-doc.org/core-2.1.3/Module.html#method-i-instance_method
        methods.each { |nonmodule_func| 
          module_function(nonmodule_func)
          public nonmodule_func
        }
      end

    rescue Exception => @error
      COURSE_LOGGER.log(@error)

      if @cud and @cud.has_auth_level? :instructor
        redirect_to action: :reload and return
      else
        redirect_to home_error_path and return
       end
    end
  end
end
