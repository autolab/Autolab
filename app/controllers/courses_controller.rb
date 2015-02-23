require 'csv'
require 'fileutils'
require 'Statistics.rb'

class CoursesController < ApplicationController
  # you need to be able to pick a course to be authorized for it
  skip_before_action :authorize_user_for_course, only: [ :index, :new, :create ]
  # if there's no course, there are no persistent announcements for that course
  skip_before_action :update_persistent_announcements, only: [ :index, :new, :create ]
  skip_before_action :authenticate_for_action
  
  def index
    courses_for_user = User.courses_for_user current_user

    if courses_for_user.any?
      @listing = categorize_courses_for_listing courses_for_user
    else
      redirect_to home_no_user_path and return
    end

    render layout: "home"
  end

  NEW_ROSTER_COLUMNS = 29

  action_auth_level :show, :instructor
  def manage

    matrix = GradeMatrix.new @course, @cud
    cols = {}

    # extract assessment final scores
    @course.assessments.each do |asmt|
      next unless matrix.has_assessment? asmt.id

      cells = matrix.cells_for_assessment asmt.id
      final_scores = cells.map { |c| c["final_score"] }
      cols[asmt.name] = final_scores
    end

    # category averages
    @course.assessment_categories.each do |cat|
      next unless matrix.has_category? cat

      cols["#{cat} Average"] = matrix.averages_for_category cat
    end

    # course averages
    cols["Course Average"] = matrix.course_averages

    # calculate statistics
    @course_stats = {}
    stat = Statistics.new
    cols.each do |key, value|
      @course_stats[key] = stat.stats(value)
    end

  end

  def new
    # check for permission
    if !current_user.administrator? then
      flash[:error] = "Permission denied."
      redirect_to root_path and return
    end
    @newCourse = Course.new
    @newCourse.late_penalty = Penalty.new
    @newCourse.version_penalty = Penalty.new
  end

  def create
    # check for permission
    if !current_user.administrator? then
      flash[:error] = "Permission denied."
      redirect_to root_path and return
    end
    
    @newCourse = Course.new(new_course_params)
    @newCourse.display_name = @newCourse.name
    
    # fill temporary values in other fields
    @newCourse.late_slack = 0
    @newCourse.grace_days = 0
    @newCourse.start_date = Time.now
    @newCourse.end_date = Time.now
    
    @newCourse.late_penalty = Penalty.new
    @newCourse.late_penalty.kind = "points"
    @newCourse.late_penalty.value = "0"
    
    @newCourse.version_penalty = Penalty.new
    @newCourse.version_penalty.kind = "points"
    @newCourse.version_penalty.value = "0"

    if @newCourse.save then
      instructor = User.where(email: params[:instructor_email]).first
      
      # create a new user as instructor if he didn't exist
      if (instructor.nil?)
        begin
          instructor = User.instructor_create(params[:instructor_email],
                                              @newCourse.name)
        rescue Exception => e
          flash[:error] = "Can't create instructor for the course: #{e.to_s}"
          render action: 'new' and return
        end

      end
      
      newCUD = @newCourse.course_user_data.new
      newCUD.user = instructor
      newCUD.instructor = true
      
      if newCUD.save then
        if @newCourse.reload_course_config then
          flash[:success] = "New Course #{@newCourse.name} successfully created!"
          redirect_to edit_course_path(@newCourse) and return
        else
          # roll back course creation and instruction creation
          newCUD.destroy
          @newCourse.destroy
          flash[:error] = "Can't load course config for #{@newCourse.name}."
          render action: 'new' and return
        end
      else
        # roll back course creation
        @newCourse.destroy
        flash[:error] = "Can't create instructor for the course."
        render action: 'new' and return
      end
        
    else
      flash[:error] = "Course creation failed. Check all fields"
      render action: 'new' and return
    end
  end

  def show
    redirect_to course_assessments_url(@course)
  end

  action_auth_level :edit, :instructor
  def edit

  end

  action_auth_level :update, :instructor
  def update
    if @course.update(edit_course_params) then
      flash[:success] = "Success: Course info updated."
      redirect_to edit_course_path(@course)
    else
      flash[:error] = "Error: There were errors editing the course."
    end
  end

  # DELETE courses/:id/
  action_auth_level :destroy, :administrator
  def destroy
    if !current_user.administrator?
      flash[:error] = "Permission denied."
      redirect_to courses_path and return
    end
    
    course = Course.find(params[:id])
    if course.nil?
      flash[:error] = "Course doesn't exist."
      redirect_to courses_path and return
    end
    
    course.destroy
    flash[:success] = "Course destroyed."
    redirect_to courses_path and return
  end

# Non-RESTful Routes Below

  def report_bug
    if request.post?
      CourseMailer.bug_report(
        params[:title],
        params[:summary],
        current_user,
        @course
      ).deliver
    end
  end


  # Only instructor (and above) can use this feature
  # to look up user accounts and fill in cud fields
  action_auth_level :userLookup, :instructor
  def userLookup

    if params[:email].length == 0 then
      flash[:error] = "No email supplied for LDAP Lookup"
      render action: :new, layout: false and return
    end
    
    # make sure that user already exists in the database
    user = User.where(email: params[:email]).first
    
    if user.nil? then
      render json: nil and return
    end

    @user_data = { :first_name => user.first_name,
                   :last_name=> user.last_name, 
                   :email => user.email }

    return render json: @user_data

  end

  action_auth_level :users, :instructor
  def users
    if(params[:search]) then
      # left over from when AJAX was used to find users on the admin users list
      @cuds = @course.course_user_data.joins(:user).order('users.email ASC').where(CourseUserDatum.conditions_by_like(params[:search]))
    else
      @cuds = @course.course_user_data.joins(:user).order('users.email ASC')
    end

  end


  action_auth_level :sudo, :instructor
  def sudo
    session[:sudo] = nil
    redirect_to course_course_user_datum_sudo_path(course_user_datum_id: @cud.id)
  end


  action_auth_level :reload, :instructor
  def reload
    if @course.reload_course_config then
      flash[:success] = "Success: Course config file reloaded!"
      redirect_to [@course] and return
    else
      render and return
    end
  end


  # Upload a CSV roster and import the users into the course
  # Colors are associated to each row of CUD after roster is processed:
  #   green - User doesn't exist in the course, and is going to be added
  #   red - User is going to be dropped from the course
  #   black - User exists in the course
  action_auth_level :uploadRoster, :instructor
  def uploadRoster
    if request.post? then
      # Check if any file is attached
      if params['upload'] && params['upload']['file'].nil? then
        flash[:error] = 'Please attach a roster!'
        redirect_to action: :uploadRoster and return
      end
      
      if params[:doIt] then
        begin
          CourseUserDatum.transaction do
            rowNum = 0
            
            until params["cuds"][rowNum.to_s].nil? do
              newCUD = params["cuds"][rowNum.to_s]
              
              if newCUD["color"] == "green" then
                # Add this user to the course
                # Look for this user
                email = newCUD[:email]
                first_name = newCUD[:first_name]
                last_name = newCUD[:last_name]
                school = newCUD[:school]
                major = newCUD[:major]
                year = newCUD[:year]
                
                if ((user = User.where(email: email).first).nil?)
                  # Create a new user
                  user = User.roster_create(email, first_name, last_name, school,
                                        major, year)
                  if (user.nil?)
                    raise "New user cannot be created in uploadRoster."
                  end
                else
                  # Override current user
                  user.first_name = first_name
                  user.last_name = last_name
                  user.school = school
                  user.major = major
                  user.year = year
                  user.save
                end
                
                # Make sure this user doesn't have a cud in the course
                if (@course.course_user_data.where(user: user).first)
                  raise "Green CUD doesn't exist in the database."
                end
                
                # Delete unneeded data
                newCUD.delete(:color)
                newCUD.delete(:email)
                newCUD.delete(:first_name)
                newCUD.delete(:last_name)
                newCUD.delete(:school)
                newCUD.delete(:major)
                newCUD.delete(:year)
                
                # Build cud
                cud = @course.course_user_data.new
                cud.user = user
                cud.assign_attributes(newCUD.permit(:lecture, :section, :grade_policy))
                
                # Save without validations
                cud.save(validate: false) 
  
              elsif newCUD["color"] == "red" then
                # Drop this user from the course
                existing = @course.course_user_data.includes(:user).where(users: { email: newCUD[:email]}).first
                
                if (existing.nil?) then
                  raise "Red CUD doesn't exist in the database."
                end
                
                existing.dropped = true
                existing.save(validate: false)
                
              else
                # Update this user's attributes. 
                existing = @course.course_user_data.includes(:user).where(users: { email: newCUD[:email]}).first

                if (existing.nil?) then
                  raise "Black CUD doesn't exist in the database."
                end
                
                user = existing.user
                if (user.nil?) then
                  raise "User associated to black CUD doesn't exist in the database."
                end
                
                # Update user data
                user.school = newCUD[:school]
                user.major = newCUD[:major]
                user.year = newCUD[:year]
                user.save!

                # Delete unneeded data
                newCUD.delete(:color)
                newCUD.delete(:email)
                newCUD.delete(:first_name)
                newCUD.delete(:last_name)
                newCUD.delete(:school)
                newCUD.delete(:major)
                newCUD.delete(:year)
                
                # assign attributes
                existing.assign_attributes(newCUD.permit(:lecture, :section, :grade_policy))
                existing.save(validate: false) # Save without validations.
              end
              
              rowNum +=1
            end
          end
          
          flash[:success] = "Success!"
          
        rescue Exception => e
          flash[:error] = "There was an error uploading the roster
file, most likely a duplicate email.  The exact error was: #{e} "
          redirect_to action: "uploadRoster" and return
        end
        
      else
        # generate doIt form from the upload
        @cuds = []
        @currentCUDs = @course.course_user_data.all.to_a
        @newCUDs = []
        
        begin
          csv = detectAndConvertRoster(params['upload']['file'].read)
          csv.each do |row|
            next if (row[1].nil? || row[1].chomp.size == 0)
            newCUD = {email: row[1].to_s,
                      last_name: row[2].to_s.chomp(" "),
                      first_name: row[3].to_s.chomp(" "),
                      school: row[4].to_s.chomp(" "),
                      major: row[5].to_s.chomp(" "),
                      year: row[6].to_s.chomp(" "),
                      grade_policy: row[7].to_s.chomp(" "),
                      lecture: row[9].to_s.chomp(" "),
                      section: row[10].to_s.chomp(" ")}
            cud = @currentCUDs.find { |cud| 
              cud.user and cud.user.email == newCUD[:email] 
            }
            if !cud then
              newCUD[:color] = "green"
            else
              @currentCUDs.delete(cud) 
            end
            @cuds << newCUD
          end
        rescue CSV::MalformedCSVError => error
          flash[:error] = "Error parsing CSV file: #{error.to_s}"
          redirect_to :action=>"uploadRoster" and return
        rescue Exception => e 
          raise e
          flash[:error] = "Error uploading the CSV file!: " +
e.to_s() + e.backtrace().join("<br>")
          redirect_to :action=>"uploadRoster" and return
        end
        
        # drop the rest if indicated
        if params[:upload][:dropMissing] == "1" then 
          # We never drop instructors, remove them first
          @currentCUDs.delete_if { |cud|
            cud.instructor? || cud.user.administrator? || cud.course_assistant?
          }
          for cud in @currentCUDs do #These are the drops
            newCUD = {email: cud.user.email,
                      last_name: cud.user.last_name,
                      first_name: cud.user.first_name,
                      school: cud.school,
                      major: cud.major,
                      year: cud.year,
                      grade_policy: cud.grade_policy,
                      lecture: cud.lecture,
                      section: cud.section,
                      color: "red"}
            @cuds << newCUD
          end
        end
      end
    end
  end

  action_auth_level :downloadRoster, :instructor
  def downloadRoster
    @cuds = @course.course_user_data.where(instructor: false, 
                                           course_assistant: false,
                                           dropped: false)
    output = ""
    for cud in @cuds do
      user = cud.user
      output += "#{@course.semester},#{cud.user.email},#{user.last_name},#{user.first_name},#{cud.school},#{cud.major},#{cud.year},#{cud.grade_policy},#{cud.lecture},#{cud.section}\n"
    end
    send_data output,:filename=>"roster.csv",:type=>'text/csv',:disposition=>'inline'
  end

  # installAssessment - Installs a new assessment, either by
  # creating it from scratch, or importing it from an existing
  # assessment directory.
  action_auth_level :installAssessment, :instructor
  def installAssessment
    @assignDir = File.join(Rails.root, "courses", @course.name)
    @availableAssessments = []
    begin
      Dir.foreach(@assignDir) { |filename|
        if File.exist?(File.join(@assignDir, filename, "#{filename}.rb")) then
          # names must be only lowercase letters and digits
          if filename =~ /[^a-z0-9]/ then
            next
          end

          # Only list assessments that aren't installed yet
          assessment = @course.assessments.where(:name => filename).first
          if !assessment then
            @availableAssessments << filename
          end
        end
      }
      @availableAssessments = @availableAssessments.sort
    rescue Exception => error
      render :text=>"<h3>#{error.to_s}</h3>", :layout=>true and return
    end
  end
  
  # email - The email action allows instructors to email the entire course, or
  # a single section at a time.  Sections are passed via params[:section].
  action_auth_level :email, :instructor
  def email
    if request.post? then
      if params[:section].length > 0 then
        section = params[:section]
      else
        section = nil
      end

      #don't email kids who dropped!
      if section then
        @cuds = @course.course_user_data.where(:dropped=>false, :section=>section)
      else
        @cuds = @course.course_user_data.where(:dropped=>false)
      end

      bccString = makeDlist(@cuds)

      @email = CourseMailer.course_announcement(
            params[:from],
            bccString,
            params[:subject],
            params[:body],
            @cud,
            @course)
      @email.deliver
    end
  end


  action_auth_level :moss, :instructor
  def moss
    @courses= Course.all
  end


  action_auth_level :runMoss, :instructor
  def runMoss
    # Return if we have no files to process.
    unless request.post? and (params["assessments"] or params["external_tar"])
      flash[:error] = "No input files provided for MOSS."
      redirect_to :action=>"moss" and return
    end
    assessmentIDs = params["assessments"]
    assessments = []
  
    # First, validate access on each of the requested assessments
    if assessmentIDs then
      for aID in assessmentIDs.keys do 
        assessment = Assessment.find(aID)
        if !assessment then
          flash[:error] = "Invalid Assessment"
          redirect_to :action=>"moss" and return
        end
        assessmentCUD = assessment.course.course_user_data.joins(:user).where(users: { email: current_user.email },
                                                                               instructor: true).first
        if !assessmentCUD and (not @cud.user.administrator? ) then 
          flash[:error] = "Invalid User"
          redirect_to :action=>"moss" and return
        end
        assessments << assessment
      end
    end

    require 'rubygems'
    require 'rubygems/package'
    require 'zlib'
    require 'zip'

    @mossCmd= "mossnet -d "
  
    # Create a temporary directory for this
    tmpDir = Dir.mktmpdir("#{@cud.user.email}Moss", File.join(Rails.root, 'tmp'))
    
    # for each assessment 
    for ass in assessments do 
      # Create a directory for ths assessment
      assDir = File.join(tmpDir,"#{ass.name}-#{ass.course.name}")
      Dir.mkdir(assDir)
  
      # Build a hash of the latest submission for each student. 
      latestSubs = {}
      subs = ass.submissions.order("version ASC")
      for sub in subs do
        latestSubs[sub.course_user_datum_id] = sub
      end
      
      # For each student who submitted
      for sub in latestSubs.values do
        if ! sub.filename then
          next
        end
        subFile = File.join(Rails.root,"courses",ass.course.name,
            ass.name,ass.handin_directory,sub.filename)
        if !File.exists?(subFile) then
          next
        end
        # Create a directory for this student
        stuDir = File.join(assDir,sub.course_user_datum.email) 
        Dir.mkdir(stuDir)
        
        # Copy their submission over
        FileUtils.cp(subFile,stuDir)

        # If we need to unarchive this file, then create archive reader
        arch_type = params["archiveCmd"][ass.id.to_s]
        arch_path = "#{stuDir}/#{sub.filename}"
        if arch_type == "tar" then
          f = File.new(arch_path)
          archive_extract = Gem::Package::TarReader.new(f)
          archive_extract.rewind
        elsif arch_type == "zip" then
          archive_extract = Zip::File.open(arch_path)
        elsif arch_type == "tar.gz" then
          archive_extract = Gem::Package::TarReader.new(Zlib::GzipReader.open arch_path)
          archive_extract.rewind
        end

        # Read archive files
        if ['tar','zip','tar.gz'].member? params["archiveCmd"][ass.id.to_s]
          archive_extract.each do |entry|
            pathname = entry.respond_to?(:full_name) ? entry.full_name : entry.name
      destination = "#{stuDir}/#{pathname}"
      begin
        open destination, 'wb' do |out|
                out.write entry.read
                out.fsync rescue nil # for filesystems without fsync(2)
              end
      rescue
        FileUtils.mkdir_p File.dirname destination
      end
    end
        end

      end
      # add this assessment to the moss command
      @mossCmd += "#{assDir}/*/#{params["files"][ass.id.to_s]} "
    end
  
    # Grasp the external code source (tarball).
    external_tar = params["external_tar"];
    if external_tar then   # Sanity check.
      # Directory to hold tar ball and all individual files.
      extTarDir = File.join(tmpDir,"external_input")
      Dir.mkdir(extTarDir)
  
      # Read in the tarfile from the given source.
      extTarPath = File.join(extTarDir, "input_file.tar")
      external_tar.rewind
      File.open(extTarPath,"wb") { |f| f.write(external_tar.read)} # Write tar file.
  
      # Directory to hold all external individual submission.
      extFilesDir = File.join(extTarDir, "submissions")
      Dir.mkdir(extFilesDir)                    # To hold all submissions
  
      # Untar the given Tar file.
      arch = Archive.new(extTarPath)
      Dir.chdir(extFilesDir)
      arch.extract
  
      # Unarchive / reorganize the submission files.
      Dir.foreach(extFilesDir) { |filename|
        if filename != "." && filename != ".."
          subDir = Dir.mktmpdir(filename[0 .. filename.rindex(/\./) - 1], extFilesDir)
          if ['tar','zip','tar.gz'].member? params["archiveCmd"][ass.id.to_s]
            arch = Archive.new(File.join(extFilesDir, filename))
            Dir.chdir subDir
            arch.extract
          else
            FileUtils.cp File.join(extFilesDir, filename), subDir
          end
        end
      }

      # Feed the uploaded files to MOSS.
      @mossCmd += "#{extFilesDir}/*/#{params["files"][ass.id.to_s]} "
    end
  
    # Ensure that all files in Moss tmp dir are readable
    system("chmod -R a+r #{tmpDir}")
  
    # Now run the Moss command
    mossWithPath = File.join(Rails.root,"vendor",@mossCmd)
    @mossExit = $?
    @mossOutput = `#{mossWithPath} 2>&1`
  
    # Clean up after ourselves (droh: leave for debugging)
    #`rm -rf #{tmpDir}`
  end


private

  def new_course_params
    params.require(:newCourse).permit(:name, :semester)
  end

  def edit_course_params
    params.require(:editCourse).permit(:name, :semester, :late_slack, :grace_days, :display_name, :start_date, :end_date,
      :disabled, :exam_in_progress, :version_threshold, :gb_message,
      late_penalty_attributes: [:kind, :value],
      version_penalty_attributes: [:kind, :value])
  end
  
  def categorize_courses_for_listing(courses)
    listing = {}
    listing[:disabled] = []

    # temporal
    listing[:current] = []
    listing[:completed] = []
    listing[:upcoming] = []

    # categorize
    courses.each do |course|
      if course.disabled?
        listing[:disabled] << course
      else
        listing[course.temporal_status] << course
      end
    end

    listing
  end

  # detectAndConvertRoster - Detect the type of a roster based on roster 
  # column matching and convert to default roster
  def detectAndConvertRoster(roster)
    parsedRoster = CSV.parse(roster)
    if (parsedRoster[0][0].nil?)
      raise "Roster cannot be recognized"
    elsif (parsedRoster[0].length == NEW_ROSTER_COLUMNS)
      # In CMU S3 roster. Columns are:
      # Semester(0), Lecture(1), Section(2), (skip)(3), (skip)(4), Last Name(5), 
      # First Name(6), (skip)(7), Andrew ID(8), (skip)(9), School(10), 
      # Major(11), Year(12), (skip)(13), Grade Policy(14), ...

      # Sanitize roster input, ignoring empty / incomplete lines.
      parsedRoster.select! { |row| row.length == NEW_ROSTER_COLUMNS }
      # Detect if there is a header row
      if (parsedRoster[0][0] == "Semester")
        offset = 1
      else
        offset = 0
      end
      numRows = parsedRoster.length - offset
      convertedRoster = Array.new(numRows) { Array.new(11) }

      for i in 0..(numRows-1)
        convertedRoster[i][0] = parsedRoster[i+offset][0]
        if (Rails.env == "production")
          convertedRoster[i][1] = parsedRoster[i+offset][8] + "@andrew.cmu.edu"
        else
          convertedRoster[i][1] = parsedRoster[i+offset][8] + "@foo.bar"
        end
        convertedRoster[i][2] = parsedRoster[i+offset][5]
        convertedRoster[i][3] = parsedRoster[i+offset][6]
        convertedRoster[i][4] = parsedRoster[i+offset][10]
        convertedRoster[i][5] = parsedRoster[i+offset][11]
        convertedRoster[i][6] = parsedRoster[i+offset][12]
        convertedRoster[i][7] = parsedRoster[i+offset][14]
        convertedRoster[i][9] = parsedRoster[i+offset][1]
        convertedRoster[i][10] = parsedRoster[i+offset][2]
      end
      return convertedRoster
    else
      # No header row. Columns are:
      # Semester(0), Email(1), Last Name(2), First Name(3), School(4), 
      # Major(5), Year(6), Grade Policy(7), (skip)(8), Lecture(9), 
      # Section(10), ...
      return parsedRoster
    end
  end

end
