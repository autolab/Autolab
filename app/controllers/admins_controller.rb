require('csv')
require('fileutils')


class AdminsController < ApplicationController
  
  CMU_ROSTER_COLUMNS = 29

  action_auth_level :show, :instructor
  def show
    @options = 
      [{"name"=>"Edit course", path: [:edit, @course], 
        "title"=>"Modify the properties for this course"},
     
       {"name"=>"Manage accounts", path: users_course_admin_path(@course),
        "title"=>"Create, modify, and delete user accounts"},

       {"name"=>"Act as user","action"=>"sudo",
        "title"=>"Temporarily become another user"},

       {"name"=>"Install assessment", path: installAssessment_course_assessments_path(@course),
        "title"=>"Create an assessment from scratch or install one from an existing directory"},

       {"name"=>"Send bulk email","action"=>"email",
        "title"=>"Send an email to everyone in the class"},

       {"name"=>"Manage categories", path: course_assessment_categories_path(@course),
        "title"=>"Create and delete assessment categories"},

       {"name"=>"Manage schedulers", path: course_schedulers_path(@course),
        "title"=>"An advanced feature used only for some 15-213 labs"},

       {"name"=>"Manage course attachments", path: course_attachments_path(@course),
        "title"=>"Distribute files to your students"},

       {"name"=>"Manage announcements", path: course_announcements_path(@course),
        "title"=>"Manage announcements via banners on either front page or all pages (persistent)."},

       {"name"=>"Run Moss cheat checker","action"=>"moss",
        "title"=>"Use the Stanford Moss server to detect copying"},

       {"name"=>"Reload course config file","action"=>"reload",
        "title"=>"Do this each time your modify the course.rb file"},

       {"name"=>"Bulk release all grades", path: bulkRelease_course_course_user_datum_gradebook_path(@course, @cud),
        "title"=>"Release all grades for all assessments"}

       # TODO: re-add CSV export
       # {"name"=>"Export grades as CSV","controller"=>"gradebook","action"=>"csv"}
    ]
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
    mod = nil
    begin
      mod = @course.reload_config_file
    rescue Exception => @error
      render and return
    end

    extend(mod)
    flash[:success] = "Success!"
    redirect_to action: :show and return
  end

  action_auth_level :uploadRoster, :instructor
  def uploadRoster
    if request.post? then
      # Check if any file is attached
      if params['upload'] && params['upload']['file'].nil? then
        flash[:error] = 'Please attach a roster!'
        redirect_to :action => 'uploadRoster' and return
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
                
                if ((user = User.where(email: email).first).nil?)
                  # Create a new user
                  user = User.roster_create(email, newCUD[:first_name],
                                            newCUD[:last_name])
                  if (user.nil?)
                    throw NewUserCreationException
                  end
                end
                
                # Make sure this user doesn't have a cud in the course
                if (@course.course_user_data.where(user: user).first)
                  throw NewUserExistInCourseException
                end
                
                # Delete unneeded data
                newCUD.delete(:color)
                newCUD.delete(:email)
                newCUD.delete(:first_name)
                newCUD.delete(:last_name)
                
                # Build cud
                cud = @course.course_user_data.new
                cud.user = user
                cud.assign_attributes(newCUD.permit(:lecture, :section, :school, :major, :year, :grade_policy))
                
                # Save without validations
                cud.save(validate: false) 
  
              elsif newCUD["color"] == "red" then
                # Drop this user from the course
                existing = @course.course_user_data.includes(:user).where(users: { email: newCUD[:email]}).first
                existing.dropped = true
                existing.save(validate: false)
                
              else
                # Update this user's attributes. 
                existing = @course.course_user_data.includes(:user).where(users: { email: newCUD[:email]}).first

                # Delete unneeded data
                newCUD.delete(:color)
                newCUD.delete(:email)
                newCUD.delete(:first_name)
                newCUD.delete(:last_name)
                
                # assign attributes
                existing.assign_attributes(newCUD.permit(:lecture, :section, :school, :major, :year, :grade_policy))
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
              cud.user.email == newCUD[:email] 
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
  # The makeDlist() function creates the actual email list that andrew mailman
  # servers can understand. 
        #
  # NOTE: This is the only truly CMU-specific function in Autolab. 
        #
  action_auth_level :email, :instructor
  def email
    if request.post? then
      if params[:section].length > 0 then
        section = params[:section]
      else
        section = nil
      end
      bccString = makeDlist(section)

      @email = CourseMailer.announcement(
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
        require 'rubygems/package'

        # If we need to unarchive this file, then do so
        if ['tar','zip','tar.gz'].member? params["archiveCmd"][ass.id.to_s]
          
          f = File.new("#{stuDir}/#{sub.filename}")
          tar_extract = Gem::Package::TarReader.new(f)
	  tar_extract.rewind
          tar_extract.each do |entry|
	    destination = "#{stuDir}/#{entry.full_name}"
	    begin
	      open destination, 'wb', entry.header.mode do |out|
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

  # makeDlist - Creates a dlist file that andrew mailman servers can read.
  # @param section The section to email.  nil if we should email the entire
  # class. 
  # @return The filename of the dlist that was created. 
  def makeDlist(section)
    #We're going to create the dlist file right quick.
   
    emails = []
    #don't email kids who dropped!
    if section then
      @cuds = @course.course_user_data.where(:dropped=>false, :section=>section)
    else
      @cuds = @course.course_user_data.where(:dropped=>false)
    end
    for cud in @cuds do 
      emails << "#{cud.user.email}"
    end


    return emails.join(",")
  end
  
  # detectAndConvertRoster - Detect the type of a roster based on roster 
  # column matching and convert to default roster
  def detectAndConvertRoster(roster)
    parsedRoster = CSV.parse(roster)
    if (parsedRoster[0][0].nil?)
      raise "Roster cannot be recognized"
    elsif (parsedRoster[0].length == CMU_ROSTER_COLUMNS)
      # In CMU S3 roster. Columns are:
      # Semester(0), Lecture(1), Section(2), (skip)(3), (skip)(4), Last Name(5), 
      # First Name(6), (skip)(7), Andrew ID(8), (skip)(9), School(10), 
      # Major(11), Year(12), (skip)(13), Grade Policy(14), ...

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
