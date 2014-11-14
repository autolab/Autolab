require 'csv'
require 'yaml'
require 'Statistics.rb'
require 'date_time_input'

class AssessmentsController < ApplicationController
  include ActiveSupport::Callbacks

  autolabRequire File.join(Rails.root, 'app/controllers/assessment/handin.rb')
  include AssessmentHandin

  autolabRequire File.join(Rails.root, 'app/controllers/assessment/handout.rb')
  include AssessmentHandout

  autolabRequire File.join(Rails.root, 'app/controllers/assessment/grading.rb')
  include AssessmentGrading

  autolabRequire File.join(Rails.root, 'app/controllers/assessment/autograde.rb')
  include AssessmentAutograde


  before_action :get_assessment, except: [ :index, :new, :create, :installAssessment, :importAsmtFromTar, :importAssessment, :getCategory, :unofficial_submit ]

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
  action_auth_level :bulkFeedback, :instructor

  # Handin
  action_auth_level :handin, :student

  # AssessmentBase
  action_auth_level :writeup, :student
  action_auth_level :handout, :student

  # Autograde
  action_auth_level :adminAutograde, :instructor
  action_auth_level :regrade, :instructor
  action_no_auth    :unofficial_submit

  # Partners
  action_auth_level :partner, :student
  action_auth_level :setPartner, :student
  action_auth_level :cancelRequest, :student
  action_auth_level :adminPartners, :instructor
  action_auth_level :deletePartner, :instructor
  action_auth_level :importPartners, :instructor

  # SVN
  action_auth_level :adminSvn, :instructor
  action_auth_level :setRepository, :instructor
  action_auth_level :importSvn, :instructor

  # Scoreboard
  action_auth_level :adminScoreboard, :instructor
  action_auth_level :scoreboard, :student

  def index
    @is_instructor = @cud.has_auth_level? :instructor
    @announcements = Announcement.where("start_date<? and end_date>? and (course_id=? or system) and !persistent", Time.now, Time.now, @course.id).order('start_date')
    @attachments = (@cud.instructor?)? @course.attachments : @course.attachments.where(released: true)
  end
  
  # GET /assessments/new
  # Installs a new assessment, either by
  # creating it from scratch, or importing it from an existing
  # assessment directory.
  action_auth_level :new, :instructor
  def new
    @assessment = Assessment.new
    @categories = @course.assessment_categories
    @moduleDir = File.join(Rails.root, "lib", "modules")
    @modules = []
    begin
      Dir.foreach(@moduleDir) { |filename|
        if (filename =~ /.*\.rb/) then
          @modules << filename.gsub(/\.rb/,"")
        end
      }
    rescue Exception 
    end
  end

  # installAssessment - Installs a new assessment, either by
  # creating it from scratch, or importing it from an existing
  # assessment directory on file system, or from an uploaded
  # tar file with the assessment directory.
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
 
  action_auth_level :importAsmtFromTar, :instructor
  def importAsmtFromTar
    # Only handle POST requests.
    if !request.post? then
      redirect_to(:action => "installAssessment") and return
    end
    require 'rubygems/package'
    require 'fileutils'
    tarFile = params['tarFile']
    if tarFile.nil?
      flash[:error] = "Please select an assessment tarball for uploading."
      redirect_to(:action => "installAssessment") and return
    end
    begin
      tarFile = File.new(tarFile.open, "rb")
      tar_extract = Gem::Package::TarReader.new(tarFile)
      tar_extract.rewind
      # Verify integrity of assessment tarball.
      file_list = []
      dir_list = []
      tar_extract.each do |entry|
        pathname = entry.full_name
        next if pathname.start_with? "."
        isdir = entry.directory?
        if isdir
          dir_list << pathname
        else
          file_list << pathname
        end
      end
      tar_extract.close
      dir_list.sort!
      file_list.sort!
      valid_file = nil
      asmt_name = nil
      asmt_rb_exist = false
      asmt_yml_exist = false
      dir_list.each do |dir|
        if dir.count("/") == 0
          if !asmt_name.nil?
            valid_file = false
            break
          else
            asmt_name = dir
          end
        end
      end
      file_list.each do |file|
        if file == "#{asmt_name}/#{asmt_name}.rb"
          asmt_rb_exist = true
        elsif file == "#{asmt_name}/#{asmt_name}.yml"
          asmt_yml_exist = true
        end
      end
      valid_file = (valid_file != false) && !asmt_name.nil? && asmt_rb_exist && asmt_yml_exist
      if !valid_file
        flash[:error] = "Invalid tarball. Please verify the existence of configuration files."
        redirect_to(:action => "installAssessment") and return
      end
    rescue Exception => e
      flash[:error] = "Error while reading the tarball -- #{e.message}."
      redirect_to(:action => "installAssessment") and return
    end
    # Check if the assessment already exists.
    if !Assessment.find_by(:name => asmt_name, :course_id => @course.id).nil?
      flash[:error] = "An assessment with the same name already exists for the course. Please use a different name."
      redirect_to(:action => "installAssessment") and return
    end
    # If all requirements are satisfied, extract assessment files.
    begin
      course_root = File.join(Rails.root, "courses", @course.name)
      tar_extract.rewind
      tar_extract.each do |entry|
        relative_pathname = entry.full_name
        isdir = entry.directory?
        isfile = entry.file?
        if isdir
          FileUtils.mkdir_p File.join(course_root, relative_pathname),
                            :mode => entry.header.mode, :verbose => false
        elsif isfile
          FileUtils.mkdir_p File.join(course_root, File.dirname(relative_pathname)),
                            :mode => entry.header.mode, :verbose => false
          File.open(File.join(course_root, relative_pathname), "wb") do |f|
            f.print entry.read
          end
          FileUtils.chmod entry.header.mode, File.join(course_root, relative_pathname),
                    :verbose => false
        elsif entry.header.typeflag == '2'
          File.symlink entry.header.linkname, File.join(course_root, relative_pathname)
        end
      end
      tar_extract.close
    rescue Exception => e
      flash[:error] = "Error while extracting tarball to server -- #{e.message}."
      redirect_to(:action => "installAssessment") and return
    end
    redirect_to(:action => "importAssessment", :assessment_name => asmt_name) and return
  end

  # importAssessment - Imports an existing assessment from local file.
  # The main task of this function is to decide what category a newly
  # installed assessment should be assigned to.
  action_auth_level :importAssessment, :instructor
  def importAssessment
    name = params['assessment_name']
    filename = File.join(Rails.root, "courses", @course.name, name, "#{name}.yml") 

    # Load up the properties file
    props = {}
    if File.exists?(filename) and File.readable?(filename) then
      f = File.open(filename, 'r')
      props = YAML.load(f.read)
      f.close
    end
    
    # If the properties file defines a category, then use it,
    # creating a new category if necessary. 
    if props['general'] and props['general']['category'] then
      requested_cat = props['general']['category']
      categories = AssessmentCategory.getList(@course)
      if categories.has_key?(requested_cat) then
        category_id = categories[requested_cat]
      else
        cat = @course.assessment_categories.new(name: requested_cat)
        if cat.save then
          category_id = cat.id
        else
          flash[:error] = "Cannot create assessment category #{requested_cat}"
          redirect_to importAssessment_course_assessments_path(course_id: @course.id)
          return
        end
      end

      params[:assessment] = {name: name, category_id: category_id}
      create and return

    # Otherwise, ask the user to give us a category before we create the
    # assessment
    else
      redirect_to getCategory_course_assessments_path(course_id: @course.id, assessment_name: name) 
      return
    end
  end
  
  # create - Creates an assessment from an assessment directory
  # residing in the course directory.
  action_auth_level :create, :instructor
  def create
    @assessment = Assessment.new(new_assessment_params)

    # Validate the name 
    assName = @assessment.name.downcase.gsub(/[^a-z0-9]/,"")
    if assName.blank? then
      flash[:error] = "Assessment name cannot be blank" 
      redirect_to action: :installAssessment and return
    end
    
    # Update name in object
    @assessment.name = assName
    
    # Reload modules list
    @modules = []
    begin
      Dir.foreach(@moduleDir) { |filename|
        if (filename =~ /.*\.rb/) then
          @modules << filename.gsub(/\.rb/,"")
        end
      }
    rescue Exception 
    end

    # Modules must be in the module list. 
    modules = params[:modules]
    modulesInclude = ""
    modulesRequire = ""
    if modules then 
      for mod in modules.keys do
        if @modules.include?(mod) then
          modulesInclude += "\tinclude #{mod}\n"
          modulesRequire += "require \"modules/#{mod}.rb\"\n"
        end
      end
    end

    # From here on, if something weird happens, we rollback
    begin 

      # We need to make the assessment directory before we try to upload
      # files 
      assDir = File.join(Rails.root,"courses", @course.name, assName)
      if !File.directory?(assDir) then
        Dir.mkdir(assDir)
      end
      
      # Open and read the default assessment config file
      defaultName = File.join(Rails.root,"lib","__defaultAssessment.rb")
      defaultConfigFile = File.open(defaultName,"r")
      defaultConfig = defaultConfigFile.read()
      defaultConfigFile.close()
      
      # Update with this assessment information
      defaultConfig.gsub!("##NAME_CAMEL##",assName.camelize)
      defaultConfig.gsub!("##NAME_LOWER##",assName)
      defaultConfig.gsub!("##MODULES_INCLUDE##",modulesInclude)
      defaultConfig.gsub!("##MODULES_REQUIRE##",modulesRequire)
     

      assessmentConfigName = File.join(assDir, "#{assName}.rb") 
      if !File.file?(assessmentConfigName) then
        # Write the new config out to the right file. 
        assessmentConfigFile = File.open(assessmentConfigName, "w")
        assessmentConfigFile.write(defaultConfig)
        assessmentConfigFile.close()      
      end

      # Make the handin directory
      handinDir = File.join(assDir,"handin")
      if !File.directory?(handinDir) then
        Dir.mkdir(handinDir)
      end
      
    rescue Exception => e
      # Something bad happened. Undo everything       
      flash[:error] = e.to_s()
      begin
        FileUtils.remove_dir(assDir)
      rescue Exception => e2
        flash[:error] = "An error occurred (#{e2}} " +
          " while recovering from a previous error (#{flash[:error]})"
      end
      redirect_to action: :installAssessment and return
    end
    
    # fill in other fields
    @assessment.course = @course
    @assessment.display_name = @assessment.name
    @assessment.handin_directory = "handin"
    @assessment.handin_filename = "handin.c"
    @assessment.visible_at = Time.now
    @assessment.start_at = Time.now
    @assessment.due_at= Time.now
    @assessment.grading_deadline = Time.now
    @assessment.end_at = Time.now
    
    if !@assessment.save
      flash[:error] = "Error saving #{@assessment.name}"
      redirect_to action: :installAssessment and return
    end

    # Stage the config file in assessmentConfig and then reload it
    name = @assessment.name
    begin
      #extend_config_module
      
      # Verify that we have a module named correctly. 
      # assign = name.gsub(/\./, '')
      # modName = assign + (@course.name).gsub(/[^A-Za-z0-9]/, "")
      # if (not Module.constants.include?(modName.camelize.to_sym)) then
      #   raise "There is no module named #{assign.camelize} in" +
      #     " #{assign}/#{assign}.rb " 
      # end
    rescue Exception => e
      flash[:error] = "Error loading #{name}.rb. This is possibly due to a typo or syntax error in your file. Contact Autolab team if the problem persists.<br />Rails error message: #{e}.".html_safe
      uninstall(name)
      redirect_to course_path(@course) and return
    end
      
    # Create the properties file if it doesn't exist
    begin     
      f = File.join(Rails.root, "courses", @course.name, 
              @assessment.name, "#{@assessment.name}.yml") 
      if !File.exists?(f) and !put_props() then
        raise "Error while executing put_props()"
      end
    rescue Exception => e
      flash[:error] = "Error saving property file: #{e}"
      uninstall(name)
      redirect_to course_path(@course) and return
    end

    # Import properties from the properties file
    begin
      import()
    rescue Exception => e
      flash[:error] = "Error importing properties: #{e}"
      uninstall(name)
      redirect_to course_path(@course) and return
    end
      
    # Initialize the problems using the deprecated assessment.rb
    # approach. For backwards compatibility only as we transition
    # to the new property-file based approach.
    begin
      # assessmentInitialize(name)
      # installProblems()
    rescue Exception => e
      puts "\n\n ERROR: \n #{e.to_s} \n #{e.backtrace} \n"
      flash[:error] = "Error initializing #{name}: #{e}"
      uninstall(name)
      redirect_to course_path(@course) and return
    end
      
    flash[:success] = "Successfully installed #{name}."
    redirect_to course_path(@course) and return
  end

  def assessmentInitialize(assignName)
    @assessment = @course.assessments.where(:name=>assignName).first
    if ! @assessment then
      raise "Assessment #{assignName} does not exist!"
    end

    if @assessment == nil then
      flash[:error] = "Error: Invalid assessment"
      redirect_to :controller=>"home",:action=>"error" and return
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
    if ! @cud.instructor? then
      redirect_to :action=>"index" and return
    end

    if Problem.where(:assessment_id=>@assessment.id).count == 0 then
      for problem in @problems do
        p = Problem.new(:name=>problem['name'],
              :description=>problem['description'],
              :assessment_id=>@assessment.id,
              :max_score=>problem['max_score'],
              :optional=>problem['optional'])
        p.save()
      end
    end
  end

  # raw_score
  # @param map of problem names to problem scores 
  # @return score on this assignment not including any tweak or late penalty.
  # We generically cast all values to floating point numbers because we don't
  # trust the upstream developer to do that for us. 
  def raw_score(scores)
    
    if @assessment.has_autograde and 
      @assessment.config_module.instance_methods.include?(:raw_score) then
      sum = @assessment.config_module.raw_score(scores)
    else
      sum = 0.0
      scores.each_value{ |value| sum += (value.to_f()) }
    end

    return sum
  end

  def grade
    @problem = @assessment.problems.find(params[:problem])
    @submission = @assessment.submissions.find(params[:submission])
    #Shows a form which has the submission on top, and feedback on bottom
    begin
      subFile =File.join(Rails.root,"courses",
            @course.name,@assessment.name,
            @assessment.handin_directory,
            @submission.filename)
      @submissionData = File.read(subFile)
    rescue
      @submissionData = "Could not read #{subFile}"
    end
    @score = @submission.scores.where(:problem_id=>@problem.id).first
  end

  def getAssessmentVariable(key)
    if @assessmentVariables then
      return @assessmentVariables.key(key)
    else
      return nil
    end
  end

  # export - export an assessment by saving its persistent
  # properties in a yaml properties file.
  action_auth_level :export, :instructor
  def export
    require 'fileutils'
    require 'rubygems/package'
    base_path = File.join(Rails.root, "courses", @course.name) 
    asmt_dir = @assessment.name
    begin
      # Update the assessment config YAML file.
      @assessment.serialize_yaml_to_path @assessment.settings_yaml_path
      # Pack assessment directory into a tarball.
      tarStream = StringIO.new("")
      Gem::Package::TarWriter.new(tarStream) do |tar|
        tar.mkdir asmt_dir, File.stat(File.join(base_path, asmt_dir)).mode
        Dir[File.join(base_path, asmt_dir, "**")].each do |file|
          mode = File.stat(file).mode
          relative_path = file.sub /^#{Regexp::escape base_path}\/?/, ''

          if File.directory?(file)
            tar.mkdir relative_path, mode
          elsif !relative_path.starts_with? File.join(@assessment.name, @assessment.handin_directory)
            tar.add_file relative_path, mode do |tarFile|
              File.open(file, "rb") { |f| tarFile.write f.read }
            end
          end
        end
      end
      tarStream.rewind
      tarStream.close
      send_data tarStream.string.force_encoding('binary'), filename: "#{@assessment.name}_#{Time.now.strftime("%Y%m%d")}.tar", content_type: 'application/x-tar'
    rescue SystemCallError => e
      flash[:error] = "Unable to update the config YAML file."
      redirect_to :action=>"index"
    rescue Exception => e
      flash[:error] = "Unable to generate tarball -- #{e.message}"
      redirect_to :action=>"index"
    else
      flash[:success] = "Successfully exported the assessment."
    end
  end

  # import - Import an assessment by loading its persistent
  # properties from properties file.
  action_auth_level :import, :instructor
  def import
    props = get_props()
    if !props or !props['general'] then 
      return
    end

    # Before importing, convert the category name to an existing
    # category ID. Create a new category if necessary.
    general = props['general']
    catName = general['category'] || AssessmentCategory.find_by_id(@assessment.category_id).name
    if !catName || catName.blank? then
      catName = "Default"
    end
    allCats = @course.assessment_categories
    catId = nil 
    for cat in allCats do
      if cat.name == catName then
        catId = cat.id
        break
      end
    end
    if catId.nil? then
      c = @course.assessment_categories.new(name: catName)
      c.save()
      # Dan's pretty certain this is unneccessary
      #c = @course.assessment_categories.where(name: catName).first
      catId = c.id
    end
    general['category_id'] = catId

    # Import general properties
    general.delete('category')
    @assessment.update_attributes(general)
    
    # Import problems
    problems = props['problems']
    if Problem.where(:assessment_id => @assessment.id).count == 0 then
      for problem in problems do
        p = Problem.new(:name=>problem['name'],
                :description=>problem['description'],
                :assessment_id=>@assessment.id,
                :max_score=>problem['max_score'],
                :optional=>problem['optional'])
        p.save()
      end
    end

    # Import autograde
    autograde = props['autograde']
    if !autograde.nil? and !autograde.empty? then
      autograde_prop = AutogradingSetup.where(:assessment_id => @assessment.id).first
      if !autograde_prop then
        autograde_prop = AutogradingSetup.new
        autograde_prop.assessment_id = @assessment.id
        autograde_prop.autograde_image = autograde['autograde_image']
        autograde_prop.autograde_timeout = autograde['autograde_timeout']
        autograde_prop.release_score = autograde['release_score']
        autograde_prop.save!
      else
        autograde_prop.update_attributes(autograde)
      end
      @assessment.update({has_autograde: true})
    end

    # Import scoreboard
    scoreboard = props['scoreboard']
    if !scoreboard.nil? and !scoreboard.empty? then
      scoreboard_prop = ScoreboardSetup.where(:assessment_id => @assessment.id).first
      if !scoreboard_prop then
        scoreboard_prop = ScoreboardSetup.new
        scoreboard_prop.assessment_id = @assessment.id
        scoreboard_prop.banner = scoreboard['banner']
        scoreboard_prop.colspec = scoreboard['colspec']
        scoreboard_prop.save!
      else
        scoreboard_prop.update_attributes(scoreboard)
      end
      @assessment.update({has_scoreboard: true})
    end
  end
  
  action_auth_level :destroy, :instructor
  def destroy
    for submission in @assessment.submissions do
      submission.destroy()
    end

    for attachment in @assessment.attachments do
      attachment.destroy()
    end

    name = @assessment.display_name
    @assessment.destroy() # awwww!!!!
    flash[:success] = "The assessment #{name} has been deleted."
    redirect_to course_path(@course) and return
  end

  action_auth_level :show, :student
  def show
    extend_config_module()

    @aud = @assessment.aud_for @cud.id

    @list = {
      'writeup'=>"View writeup",
      'handout'=>"Download handout",
      'handin'=>"Handin your work",
      'history'=>"View handin history"
    }

    # Add tooltips for the general user options
    @list_title = {}
    @list_title['writeup'] = "View the assessment writeup"
    @list_title['handout'] = "Download handout materials and starter code"
    @list_title['handin'] = "Handin your work for credit"
    @list_title['history'] = "View your submissions, scores, and feedback from the course staff"

    if @assessment.config_module.instance_methods.include?(:listOptions) then
      list = @list
      @list = @assessment.config_module.listOptions(list)
    end

    if @assessment.disable_handins? then
      @list.delete("handin")
    end
 
    if @cud.instructor? then
      listAdmin
    end
    if @cud.course_assistant? then
      listCA
    end
    
    listOptions()

    render :action=>"listOptions" and return
  end
  

  # This is easy to override, and no conflicts can occur
  def listOptions

    if @assessment.has_partners then
      partnersListOptions()
    end
  
    if @assessment.has_svn then
      svnListOptions()
    end
  
    if @assessment.has_scoreboard then
      scoreboardListOptions()
    end
  end


  def listAdmin
  
    if ! @cud.instructor? then 
      redirect_to :action=>"index" and return 
    end


    @adminlist = {
      "viewGradesheet" => "Grade submissions",
      "releaseAllGrades" => "Release all grades",
      "withdrawAllGrades" => "Withdraw all grades",
      "edit" => "Edit assessment",
      "export"=>"Export assessment",
      "reload" => "Reload config file",
      "extensions" => "Manage extensions",
      "submissions" => "Manage submissions",
      "attachments" => "Manage assessment attachments",
      "statistics" => "View statistics",
      "bulkGrade" => "Bulk import grades",
      "bulkExport" => "Bulk export grades"
    }

    # Add tooltips for the instructor admin options
    @admin_title = {}
    @admin_title['viewGradesheet'] = "View and enter grades on the gradesheet"
    @admin_title['releaseAllGrades'] = "Make all scores for this assessment visible to students"
    @admin_title['withdrawAllGrades'] = "Hide all scores for this assessment from students"
    @admin_title['zero_fill_missing_scores'] = "For each student who has not handed in anything, create a submission and assign a score of zero"
    @admin_title['edit'] = "View and modify the properties for this assessment, including its problems"
    @admin_title['export'] = "Export persistent properties that will be imported when you install this assessment in a future term"
    @admin_title['reload'] = "Reload the assessment config file (provided for backward compatibility with legacy assessments)"
    @admin_title['extensions'] = "Give extensions to students"
    @admin_title['submission'] = "Create, view, export, and re-autograde submissions"
    @admin_title['attachments'] = "Distribute files to your students"
    @admin_title['statistics'] = "View detailed stats for this assessment"
    @admin_title['bulkGrade'] = "Upload scores or feedback for multiple students from a CSV file"
    @admin_title['bulkExport'] = "Export grades (with sub-scores) \nfor all students to a CSV file"
    
    if @assessment.has_autograde then
      autogradeListAdmin
    end

    if @assessment.has_partners then
      partnersListAdmin
    end

    if @assessment.has_scoreboard then
      scoreboardListAdmin
    end

    if @assessment.has_svn then
      svnListAdmin
    end

  end

  # autogradeListAdmin - adds the "admin autograding" option to
  # the assessment admin menu
  def autogradeListAdmin
    @adminlist["adminAutograde"] = "Admin autograding"
    @admin_title["adminAutograde"] = "Modify autograding properties such as the VM image and the timeout value"
  end

  def partnersListAdmin
    @adminlist["adminPartners"] = "Admin partners"
    @admin_title["adminPartners"] = "View and modify the different partner groups"
  end

  def svnListAdmin
    @adminlist["adminSvn"] = "Admin svn"
    @admin_title["adminSvn"] = "Manage the SVN repositiory"
  end

  # scoreboardListAdmin - Adds the "admin scoreboard" option to the
  # assessment admin menu. Only autograded labs have configurable
  # scoreboards.
  def scoreboardListAdmin
    @adminlist["adminScoreboard"] = "Admin scoreboard"
    @admin_title["adminScoreboard"] = "Configure the appearance of the scoreboard"
  end

  def listCA
    if ! @cud.course_assistant? then
      redirect_to :action=>"index" and return 
    end
    @options = 
      [
       { 'url' => url_for(:action => 'viewGradesheet', :section => '1', :escape => false), 
         'name' => "Grade section #{@cud.section} submissions",
         :title => "View and enter grades for your section. Make sure your instructor has assigned you to a section in your Autolab account"},
       { 'url' => url_for(:action => 'viewGradesheet'), 
         'name' => 'Grade all submissions', 
         :title => "View and enter grades for all sections"},
       { 'url' => url_for(:action => 'releaseSectionGrades'), 
         'name' => 'Release section grades',
         :title => "Make all scores visible to the students in your section. This will work only if your instructor has assigned you to a lecture and section in your Autolab account."},
       { 'url' => url_for(:action => 'reload'), 
         'name' => 'Reload config file',
         :title => "Reload the assessment configuration file (provided for backward compatibility with legacy assessments)"}
    ]
    if !@assessment.disable_handins
      @options << { 'url' => url_for(:action => 'downloadSubmissions'), 
        'name' => 'Download submissions',
        :title => "Download all submissions"}
    end  

  end

  # scoreboardListOptions - Adds the view scoreboard option to the
  # assessment menu
  def scoreboardListOptions
    @list["scoreboard"] = "View scoreboard"
    @list_title["scoreboard"] = "View the class scoreboard"
  end

  action_auth_level :history, :student
  def history
    # Remember the student ID in case the user wants visit the gradesheet
    if params[:cud_id] then 
      session["gradeUser#{@assessment.id}"] = params[:cud_id]
    end

    @startTime = Time.now
    if @cud.instructor? and params[:cud_id] then
      @effectiveCud = @course.course_user_data.find(params[:cud_id])
    else
      @effectiveCud = @cud
    end
    @submissions = @assessment.submissions.where(course_user_datum_id: @effectiveCud.id).order("version DESC")
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
    for result in results do
      subId = result["submission_id"].to_i
      unless @scores.has_key?(subId) then
        @scores[subId]= {}
      end
      
      @scores[subId][result["problem_id"].to_i] = {
        :score=>result["score"].to_f,
        :feedback=>result["feedback"],
        :feedback_file=>result["feedback_file_name"],
        :score_id=>result["score_id"].to_i,
        :released=>result["released"].to_i,
        #score_model: Score.find(result["score_id"].to_i)
      }
    end

    # Check if we should include regrade as a function
    @autograded = @assessment.has_autograde
    
    if params[:partial] then
      @partial = true
      render "history", layout: false and return
    end
  end

  action_auth_level :viewFeedback, :student
  def viewFeedback
    #User requested to view feedback on a score
    @score = Score.unscoped.where(:submission_id=>params[:submission],
                                  :problem_id=>params[:feedback]).first
    if !@score then
      redirect_to :action=>"index" and return
    end
    if (@score.submission.course_user_datum_id != @cud.id) and
      (not @cud.instructor? ) and 
      (not @cud.course_assistant?) and
      (not @cud.administrator? ) then
        redirect_to :action=>"index" and return 
    end 
    
    @submission = @score.submission
  end

  action_auth_level :downloadFeedbackFile, :student
  def downloadFeedbackFile
    @score = Score.find_with_feedback(params[:id])
    logger.debug("here")
    if @score.feedback_file.nil?  then 
      redirect_to :action=>"viewFeedback" and return
    end
    if (@score.feedback_file_type.nil?) then
      send_data(@score.feedback_file,{
        :filename=>@score.feedback_file_name,
        :disposition=>'inline'} )
    else
      send_data(@score.feedback_file,{
        :filename=>@score.feedback_file_name,
        :type=>@score.feedback_file_type,
        :disposition=>'inline'} )
    end
  end

  action_auth_level :reload, :instructor
  def reload
    begin
      @assessment.construct_config_file
    rescue Exception => @error
      # let the reload view render
    else
      flash[:success] = "Success: Config file reloaded!"
      redirect_to action: :show and return
    end
  end

  action_auth_level :edit, :instructor
  def edit
    # default to the basic tab
    params[:active_tab] ||= "basic"

    # make sure the 'active_tab' is a real tab
    if not ["basic", "handin", "penalties", "problems"].include? params[:active_tab] then
      params[:active_tab] = "basic"
    end

    # make sure the penalties are set up
    @assessment.build_late_penalty unless @assessment.late_penalty
    @assessment.build_version_penalty unless @assessment.late_penalty
  end

  def update
    p = params[:assessment]

    # [ :start_at, :due_at, :end_at ].each do |field|
      # p[field] = DateTimeInput.hash_to_datetime p[field] if p[field]
    # end

    flash[:success] = "Saved!" if @assessment.update_attributes(params.require(:assessment).permit!)

    render "edit"
  end

  def edit_old
    if not request.patch?
      # need a dummy variable to render the text boxes 
      @assessment.late_penalty ||= Penalty.new
      @assessment.version_penalty ||= Penalty.new
    end  

    if request.patch?
      # destroy old penalites if they're now blank 
      if params[:newAssessment][:late_penalty_attributes][:value].blank?
        params[:newAssessment][:late_penalty_attributes][:_destroy] = true
      end
      if params[:newAssessment][:version_penalty_attributes][:value].blank?
        params[:newAssessment][:version_penalty_attributes][:_destroy] = true
      end

      if params[:newAssessment]['category_id'] == "-1" then
        cat = @course.assessment_categories.new(name: params[:new_category])
        if cat.save then
          params[:newAssessment]['category_id']= cat.id
        else
          params[:newAssessment]['category_id'] = nil
        end
      end
      if @assessment.update_attributes(params[:newAssessment]) then
        put_props()
        flash[:success] = "Success: Assessment updated."
      else
        flash[:error] = "There were errors updating the assessment"
      end
      redirect_to :controller=>"assessment", :action=>"edit"

    end

    @categoryDump = @course.assessment_categories
    @categories = {}
    for cat in @categoryDump do
      @categories[cat.name] = cat.id
    end
    @categories["Create New Category"] = -1
  end


  action_auth_level :releaseAllGrades, :instructor
  def releaseAllGrades
    # release all grades
    num_released = releaseMatchingGrades { |_| true }

    if (num_released > 0) 
        flash[:success] = "%d %s released." % [num_released, (num_released > 1 ? "grades were" : "grade was")]
    else 
        flash[:error] = "No grades were released. They might have all already been released."
    end
    redirect_to :action=>"viewGradesheet"
  end

  action_auth_level :releaseSectionGrades, :course_assistant
  def releaseSectionGrades
    unless @cud.section? and !@cud.section.empty? and @cud.lecture and !@cud.lecture.empty?
      flash[:error] = "You haven't been assigned to a lecture and/or section. Please contact your instructor." 
      redirect_to :action => "index"
      return
    end

    num_released = releaseMatchingGrades { |submission, _| @cud.CA_of? submission.user }

    if (num_released > 0) 
        flash[:success] = "%d %s released." % [num_released, (num_released > 1 ? "grades were" : "grade was")]
    else 
        flash[:error] = "No grades were released. " +
                        "Either they were all already released or you might be assigned to a lecture " +
                        "and/or section that doesn't exist. Please contact an instructor."
    end
    redirect_to :action=>"viewGradesheet"
  end

  action_auth_level :withdrawAllGrades, :instructor
  def withdrawAllGrades
    @assessment.submissions.each do |submission|
      scores = submission.scores.where(:released => true)
      scores.each do |score|
        score.released = false
        updateScore(@assessment.course.course_user_data, score)
      end
    end

    flash[:success] = "Grades have been withdrawn."
    redirect_to :action=>"viewGradesheet"
  end

  action_auth_level :extension, :instructor
  def extension
    redirect_to :controller=>"extension",
      :action=>"index",
      :assessment=>@assessment.id
  end

  action_auth_level :downloadSubmissions, :course_assistant
  def downloadSubmissions
    redirect_to :controller => "submission",
                :action => "downloadSubmissions",
                :assessment_id => @assessment.id
  end

  def writeup
    if Time.now() < @assessment.start_at && !@cud.instructor? then
      @output = "This assessment has not started yet."
      return
    end

    print "\n\n\n"
    print @assessment.writeup_path

    if @assessment.writeup_is_url? then
      redirect_to @assessment.writeup
      return
    end

    if @assessment.writeup_is_file? then
      filename = @assessment.writeup_path
      send_file(filename,
                      :type => mime_type_from_ext(File.extname(filename)),
            :disposition => 'inline',
            :file => File.basename(filename))
      return
    end

    @output = "There is no writeup for this assessment."
  end

  def action_missing(methId)
    if(self.methods.include?(methId.to_sym)) then
      puts "meth: #{methId}"
      eval("#{methId}")
    else
      flash[:error] = "Unknown action #{methId}"  
      render :template=>"home/error"  and return
    end
  end

  action_auth_level :attachments, :instructor
  def attachments
    redirect_to course_attachments_path(@course) and return
    @attachments = @assessment.attachments
  end

  # uninstall - uninstalls an assessment
  action_auth_level :uninstall, :instructor
  def uninstall(name)
    if !name.blank? then
      @assessment.destroy()
      f = File.join(Rails.root, "assessmentConfig/",
               "#{@course.name}-#{name}.rb")
      File.delete(f)
    end
  end

  action_auth_level :go_to_file, :course_assistant
  def go_to_file 
    @submission = Submission.find(params[:id])
    if (@submission.nil?)
      flash[:error] = "Could not find that submission."
      redirect_to :controller => :home, :action => :error and return
    end
    if (@submission.is_archive)
      redirect_to :action => "listArchive",
                  :id => @submission.id,
                  :controller => :submission 
      return
    elsif (@submission.is_syntax)
      redirect_to :action => "view",
                  :id => @submission.id,
                  :controller => :submission
      return
    else
      redirect_to :action => "download", 
                  :id => @submission.id, 
                  :controller => :submission
    end
  end

  # getCategory - Determines the category name for a new
  # assessment. Expects the assessment name to be passed in
  # params['assessment']
  action_auth_level :getCategory, :instructor
  def getCategory
    if request.post? then
      name = params[:assessment_name]
      category_id = params[:category_id]
      new_category = params[:new_category]
      if !new_category.blank? then
        cat = @course.assessment_categories.new(name: new_category)
        if cat.save then
          category_id = cat.id
        else
          flash[:error] = "Category #{new_category} already exists. Please select from the existing categories."
          redirect_to getCategory_course_assessments_path(course_id: @course.id)
          return
        end
      end
      params[:assessment] = {name: name, category_id: category_id}
      create
      return
    end

    # Intialize the list of categories for the form
    @categories = getCategoryList()
  end


  # method called when student makes
  # unofficial submission in the database
  def unofficial_submit
    
    feedback_str = request.body.read

    @course = Course.where(:id => params[:course_id]).first
    @assessment = Assessment.where(:id => params[:id]).first
    @user = User.where(:email => params[:user]).first

    if !@course  then
      puts "ERROR: invalid course"
      exit
    end

    if !@user then
      puts "ERROR: invalid username (#{user}) for class #{course.id}"
      exit
    end

    if !@assessment then
      puts "ERROR: Invalid Assessment (#{assessment}) for course #{course.id}"
      exit
    end

    if !@assessment.allow_unofficial then
      puts "ERROR: This assessment does not allow Unofficial Submissions"
      exit
    end

    @result = params[:result]

    if !@result then
      puts "ERROR: No result!"
      exit
    end

    # Everything looks OK, so append the autoresult to the log.txt file for this lab
    @logger = Logger.new("#{Rails.root}/courses/#{@course.name}/#{@assessment.name}/log.txt")
    @logger.add(Logger::INFO) { "#{@user.email},0,#{@result}" }

    # Load up the lab.rb file
    modName = @assessment.name + (@course.name).gsub(/[^A-Za-z0-9]/,"")
    require("#{Rails.root}/assessmentConfig/#{@course.name}-#{@assessment.name}.rb")
    eval("extend #{modName.camelcase}")

    begin
      # Call the parseAutoresult function defined in the lab.rb file.  If
      # the list of scores it returns is empty, then we the lab developer is
      # asking us not to create an unofficial submission in the
      # database. Simply return a successful status string to the client and
      # exit.
      scores = parseAutoresult(@result,false)

      if scores.keys.length == 0 then 
        render :nothing => true and return
      end

      # Try to find an existing unofficial submission (always version 0). 
      submission = @assessment.submissions.where(:version=>0,:user_id=>@user.id).first
      if !submission then
        submission = @assessment.submissions.new(:version=>0,
              :autoresult=>@result,
              :user_id=>@user.id,
              :submitted_by_id=>0)
        submission.save!()
      else
        #update this one
        submission.autoresult= @result
        submission.created_at = Time.now()
        submission.save!()
      end


      # Update the scores in the db's unofficial submission using the list
      # returned by the parseAutoresult function
      for key in scores.keys do
        problem = @assessment.problems.where(:name => key).first
        score = submission.scores.where(:problem_id => problem.id).first
        if !score then 
          score = submission.scores.new(:problem_id=>problem.id)
        end
        score.score = scores[key]
        score.released = true
        score.grader_id= 0
        score.save!()
      end
    rescue Exception  => e
      print e
    end


    render :nothing => true and return

  end


  # method called when student makes
  # unofficial submission in the database
  # action_no_auth :official_submit
  def official_submit
    
    @course = Course.where(:id => params[:course]).first
    @assessment = Assessment.where(:id => params[:assessment]).first
    @user = User.where(:id => params[:user]).first
    
    if !@course  then
      puts "ERROR: invalid course"
      exit
    end

    if ! @user then
      puts "ERROR: invalid username (#{user}) for class #{@course.id}"
      exit
    end

    if !@assessment then
      puts "ERROR: Invalid Assessment (#{assessment}) for course #{@course.id}"
      exit
    end


    handinDir = "/afs/andrew.cmu.edu/scs/cs/autolabEmail/handin/"
    handinDir += @user.email + "_" + @assessment.name + "/"

    if (params[:submit]) then
      #They've copied their handin over, lets go grab it. 
      # Load up the lab.rb file
      begin
        modName = @assessment.name + (@course.name).gsub(/[^A-Za-z0-9]/,"")
        require(Rails.root + "/assessmentConfig/#{@course.name}-#{@assessment.name}.rb")
        eval("extend #{modName.camelcase}")

        # Eventually, we'll make *this* a module so that we can do verifications
        # properly. Until then...

        handinFile = cgi.params["submit"][0]

        # we're going to fake an upload object so we can save it. God I hate this
        # system.
        ###
        #  class FakeUpload
        #  def initialize(filename)
        #    @filename = filename
        #  end
        #  def content_type
        #    "text/plain"
        #  end
        #  def read
        #    IO.read(@filename)
        #  end

        #  def rewind
        #    # do nothing, we open the file from scratch on every read
        #  end
        #end
        ###
        upload = {'file'=>FakeUpload.new(handinDir + handinFile)}
        @submission = Submission.create(:assessment_id=>@assessment.id,
          :user_id=>@user.id);
        @submission.saveFile(upload)
        afterHandin(@submission)
      rescue Exception  => e
        # So, Autolab is a web-service, and we are accessing it via not a web
        # request, so things go wrong.... a lot. Therefore, if an exception
        # occurs, I really don't care. Love, Hunter.
      end
      File.delete(handinDir + handinFile)

      if(@submission) then
        puts "Submission received, ID##{@submission.id}"
      else
        puts "There was an error saving your submission. Please contact your
        course staff"
      end

      numSubmissions = Submission.where(:user_id=>@user.id, :assessment_id=>@assessment.id).count

      if @assessment.max_submissions != -1 then
        if numSubmissions >= @assessment.max_submissions then
          puts " - You have 0 submissions left."
        else
          numSubmissions = @assessment.max_submissions - numSubmissions
          puts " - You have #{numSubmissions} submissions left"
        end
      end
    
    else
      
      #Create a handin directory for them. 

      # The handin Directory really should not exist, as this script deletes it
      # when it's done.  However, if it's there, we'll try to remove an empty
      # folder, else fail w/ error message. 
      if (Dir.exist?(handinDir)) then
        begin
          FileUtils.rm_rf(handinDir)
        rescue SystemCallError 
          puts "WARNING: could not clear previous handin directory, please" +
          "verify results on autolab.cs.cmu.edu "
        end
      end

      begin
        Dir.mkdir(handinDir)
      rescue SystemCallError
        puts "ERROR: Could not create handin directory. Please contact
        autolab-dev@andrew.cmu.edu with this error" 
      end

      system("fs sa #{handinDir} #{@user.email} rlidw")
      puts handinDir
    end

    render :nothing => true

  end

  #
  # adminAutograde - edit the autograding properties for this assessment
  #
  def adminAutograde
    # POST request. Try to save the updated fields. 
    if request.post? then
      @autograde_prop = AutogradingSetup.where(:assessment_id => @assessment.id).first      
      if (@autograde_prop.update_attributes(autograde_prop_params)) then
        flash[:success] = "Success: Updated autograding properties."
        redirect_to :action=>"adminAutograde" and return
      else
        flash[:error] = "Errors prevented the autograding properties from being saved."
      end

      # GET request. If an autograding properties record doesn't
      # exist for this assessment, then create default one.
    else
      @autograde_prop = AutogradingSetup.where(:assessment_id => @assessment.id).first
      if !@autograde_prop then
        @autograde_prop = AutogradingSetup.new
        @autograde_prop.assessment_id = @assessment.id
        @autograde_prop.autograde_image = "changeme.img"
        @autograde_prop.autograde_timeout = 180
        @autograde_prop.release_score = true
        @autograde_prop.save!
      end

    end

    # Regardless if GET or POST, show the page
    render(:file=>"lib/modules/views/adminAutograde.html.erb", :layout=>true)
  end

  # adminScoreboard - Edit the scoreboard properties for this assessment
  def adminScoreboard
    if !(@cud.instructor?) then
      flash[:error] = "You are not authorized to view this page"
      redirect_to :action=>"error",:controller=>"home" and return
    end

    if request.post? then
      # Update the scoreboard properties in the db
      colspec = params[:scoreboard_prop][:colspec]
      @scoreboard_prop = ScoreboardSetup.where(:assessment_id => @assessment.id).first
      if @scoreboard_prop.update_attributes(scoreboard_prop_params) then
        flash[:success] = "Updated scoreboard properties." 
        redirect_to :action=>"adminScoreboard" and return
      else
        flash[:error] = "Errors prevented the scoreboard properties from being saved."
      end
    else
      # Get the current scoreboard properties for this
      # assessment. If not present, then create a default entry in
      # the db before displaying the form
      @scoreboard_prop = ScoreboardSetup.where(:assessment_id => @assessment.id).first
      if !@scoreboard_prop then
        @scoreboard_prop = ScoreboardSetup.new
        @scoreboard_prop.assessment_id = @assessment.id
        @scoreboard_prop.banner = ""
        @scoreboard_prop.colspec = ""
        @scoreboard_prop.save!
      end

      # Set the @column_summary instance variable for the view
      @column_summary = emitColSpec(@scoreboard_prop.colspec)
    end

  end

  #
  # scoreboard - This function draws the scoreboard for an assessment.
  #
  def scoreboard
    extend_config_module
    @students = CourseUserDatum.joins("INNER JOIN submissions ON course_user_datum.id=submissions.course_user_datum_id")
                    .where("submissions.assessment_id=?",@assessment.id)
                    .group("users.id")
                    #.order("users.andrewID ASC")

    # It turns out that it's faster to just get everything and let the
    # view handle it
    problemQuery = "SELECT scores.score AS score, 
				submissions.version AS version, 
				submissions.created_at AS time,
				submissions.autoresult AS autoresult,
				problem_id AS problem_id,
				problems.name AS problem_name,
				submissions.course_user_datum_id AS course_user_datum_id
				FROM scores,submissions,problems
				WHERE submissions.assessment_id=#{@assessment.id}
				AND submissions.id = scores.submission_id
				AND problems.id = scores.problem_id
				ORDER BY submissions.created_at ASC"
    result = ActiveRecord::Base.connection.select_all(problemQuery); 
    @grades = {}
    for row in result do
      uid = row["course_user_datum_id"].to_i
      if ! @grades.has_key?(uid) then
        user = @course.course_user_data.find(uid)
        @grades[uid] = {}
        @grades[uid][:nickname] = user.nickname
        @grades[uid][:andrewID] = user.email
        @grades[uid][:fullName] = user.first_name + " " + user.last_name
        @grades[uid][:problems] = {}
      end
      if @grades[uid][:version] != row["version"] then
        @grades[uid][:time] = row["time"].localtime
        @grades[uid][:version] = row["version"].to_i
        @grades[uid][:autoresult] = row["autoresult"]
      end
      #			@grades[uid][:problems][row["problem_id"].to_i] = row["score"].to_i
      @grades[uid][:problems][row["problem_name"]] = row["score"].to_f.round(1)
    end


    # Build the html for the scoreboard header 
    begin
      if @assessment.config_module.instance_methods.include?(:scoreboardHeader) then
        @header =  @assessment.config_module.scoreboardHeader()
      else
        @header = scoreboardHeader()
      end
    rescue Exception => e
      if (@cud.instructor? ) then
        @errorMessage = "An error occurred while calling " +
          "scoreboardHeader()"
        @error = e
        render :template=>"home/error" and return
      end
      #For students just ignore the header. 
      @header = "<table class=prettyBorder >"
    end


    # Build the scoreboard entries for each student
    for grade in @grades.values do
      begin
	
        if @assessment.config_module.instance_methods.include?(:createScoreboardEntry) then
          grade[:entry] = @assessment.config_module.createScoreboardEntry(
					      grade[:problems],
					      grade[:autoresult]) 
        else 
          grade[:entry] = createScoreboardEntry(
                                              grade[:problems],
                                              grade[:autoresult])	
        end
      rescue Exception => e
        # Screw 'em! usually this means the grader failed. 
        grade[:entry] = {}
        # But, if this was an instructor, we want them to know about
        # this. 
        if (@user.instructor?) then
          @errorMessage = "An error occurred while calling " +
            "createScoreboardEntry(#{grade[:problems].inspect},"+
            "#{grade[:autoresult]})"
          @error = e
          render :template=>"home/error" and return 
        end
      end
    end

    # We want to sort @grades.values instead of just @grades because @grades
    # is a hash, and we only care about the values. This is also why we
    # included the :nickname and :andrewID in the hash instead of looking
    # them up based on the uid index. See
    # http://greatwhite.ics.cs.cmu.edu/rubydoc/ruby/classes/Hash.html#M001122
    # for more information.
    
    # Catch errors along the way. An instructor will get the errors, a
    # student will simply see an unsorted scoreboard. 

    
    @sortedGrades = @grades.values.sort {|a,b|
      begin
        scoreboardOrderSubmissions(a,b)
      rescue Exception => e
        if @cud.instructor? then
          @errorMessage = "An error occurred while calling "+
            "scoreboardOrderSubmissions(#{a.inspect},"+
            "#{b.inspect})"
          @error = e
          render :template=>"home/error" and return
        end
        0 #Just say they're equal!
      end
    }

  end

protected

  # We only do this so that it can be overwritten by modules
  def updateScore(user, score)
    score.save!()
    return true
  end

  # This does nothing on purpose
  def loadHandinPage()
  end

  # put_props - Helper function that dumps an assessment's
  # persistent properties to the properties file. Return true if
  # successful.
  def put_props
    # Generic properties
    props = {}
    props["general"] = {
      "name" => @assessment.name,
      "display_name" => @assessment.display_name,
      "description" => @assessment.description,
      "handin_filename" => @assessment.handin_filename,
      "handin_directory" => @assessment.handin_directory,
      "max_grace_days" => @assessment.max_grace_days,
      "handout" => @assessment.handout,
      "writeup" => @assessment.writeup,
      "allow_unofficial" => @assessment.allow_unofficial,
      "max_submissions" => @assessment.max_submissions,
      "disable_handins" => @assessment.disable_handins,
      "max_size" => @assessment.max_size
    }

    # Make sure we don't have any nil values in the
    # hash. Otherwise, the model will complain when we try to
    # update properties.
    props["general"]["display_name"] = "" if !props["general"]["display_name"]
    props["general"]["description"] = "" if !props["general"]["description"]
    props["general"]["handin_filename"] = "" if !props["general"]["handin_filename"]
    props["general"]["handin_directory"] = "" if !props["general"]["handin_directory"]
    props["general"]["max_grace_days"] = 0 if !props["general"]["max_grace_days"]
    props["general"]["handout"] = "" if !props["general"]["handout"]
    props["general"]["writeup"] = "" if !props["general"]["writeup"]
    props["general"]["allow_unofficial"] = false if !props["general"]["allow_unofficial"]
    props["general"]["disable_handins"] = false if !props["general"]["disable_handins"]
    props["general"]["max_submissions"] = -1 if !props["general"]["max_submissions"]
    props["general"]["max_size"] = 2 if !props["general"]["max_size"]

    # Category name
    c = AssessmentCategory.find_by_id(@assessment.category_id)
    props["general"]["category"] = c.name
    
    # Array of problems (an array because order matters)
    props["problems"] = Array.new
    probs = Problem.where(:assessment_id=>@assessment.id)
    for p in probs do 
      pelem = {}
      pelem["name"] = p.name
      pelem["description"] = p.description
      pelem["max_score"] = p.max_score
      pelem["optional"] = p.optional
      props["problems"] << pelem
    end
    
    # Scoreboard properties (if any)
    props["scoreboard"] = {}
    scoreboard_prop = ScoreboardSetup.find_by_assessment_id(@assessment.id)
    if scoreboard_prop then
      props["scoreboard"] = {
        "banner" => scoreboard_prop["banner"],
        "colspec" => scoreboard_prop["colspec"]
      }
    end

    # Autograde properties (if any)
    props["autograde"] = {}
    autograde_prop = AutogradingSetup.find_by_assessment_id(@assessment.id)
    if autograde_prop then
      props["autograde"] = {
        "autograde_image" => autograde_prop["autograde_image"],
        "autograde_timeout" => autograde_prop["autograde_timeout"],
        "release_score" => autograde_prop["release_score"]
      } 
    end

    # Now dump the properties 
    filename = File.join(Rails.root, "courses", @course.name, 
               @assessment.name, "#{@assessment.name}.yml") 
    begin
      f = File.open(filename, 'w')
      f.puts YAML.dump(props)
      f.close
    rescue Exception=>e
      return false
    end
    return true
  end

  # emitColSpec - Emits a text summary of a column specification string. 
  def emitColSpec(colspec) 
    return "Empty column specification" if colspec == nil

    begin 
      # Quote JSON keys and values if they are not already quoted
      quoted = colspec.gsub(/([a-zA-Z0-9]+):/, '"\1":').gsub(/:([a-zA-Z0-9]+)/, ':"\1"')
      parsed = ActiveSupport::JSON.decode(quoted)
    rescue Exception=>e
      return "Invalid column spec"
    end
    
    # If there is no column spec, then use the default scoreboard
    if !parsed then
      str = "TOTAL [desc] "
      for problem in @assessment.problems do
        str += "| #{problem.name.to_s.upcase}" 
      end
      return str
    end			


    # In this case there is a valid colspec
    first = true
    i = 0
    for hash in parsed["scoreboard"] do
      if first then
        str = ""
        first = false
      else 
        str += " | "
      end
      str += hash["hdr"].to_s.upcase
      if i < 3 then 
        str += hash["asc"] ? " [asc]" : " [desc]" 
      end
      i += 1
    end
    return str
  end
  
  #
  # scoreboardOrderSubmissions - This function provides a "<=>"
  # functionality to sort rows on a scoreboard.  Row pairs are
  # passed in (a,b) and must return -1, 0, or 1 depending if a is
  # less than, equal to, or greater than b.  Parms a and b are of
  # form {:uid, :andrewID, :version, :time, :problems, :entry},
  # where problems is a hash that contains keys for each problem id
  # as well as for each problem name.  An entry is the array
  # returned from createScoreboardEntry.
  # 
  # This function can be overwritten by the instructor in the lab
  # config file.
  #
  def scoreboardOrderSubmissions(a, b)
    
    # If the assessment is not autograded, or the instructor did
    # not create a custom column spec, then revert to the default,
    # which sorts by total problem, then by submission time.
    if (!@assessment.has_autograde or
        !@scoreboard_prop or @scoreboard_prop.colspec.blank?) then
      aSum=0; bSum=0;
      for key in a[:problems].keys do
        aSum += a[:problems][key].to_f
      end
      for key in b[:problems].keys do
        bSum += b[:problems][key].to_f
      end
      if (bSum != aSum) then
        bSum <=> aSum # descending
      else
        a[:time] <=> b[:time]
      end

      # In this case, we have an autograded lab for which the
      # instructor has created a custom column specification.  By
      # default, we sort the first three columns from left to right
      # in descending order. Lab authors can modify the default
      # direction with the "asc" key in the column spec.
    else
      a0 = a[:entry][0].to_f
      a1 = a[:entry][1].to_f
      a2 = a[:entry][2].to_f
      b0 = b[:entry][0].to_f
      b1 = b[:entry][1].to_f
      b2 = b[:entry][2].to_f
      
      begin
        parsed = ActiveSupport::JSON.decode(@scoreboard_prop.colspec)
      rescue Exception=>e

      end
      
      if a0 != b0 then
        if (parsed and parsed["scoreboard"] and 
            parsed["scoreboard"].size > 0 and
            parsed["scoreboard"][0]["asc"]) then
          a0 <=> b0 # ascending order
        else
          b0 <=> a0 # descending order
        end
      elsif a1 != b1 then
        if (parsed and parsed["scoreboard"] and 
            parsed["scoreboard"].size > 1 and 
            parsed["scoreboard"][1]["asc"]) then
          a1 <=> b1 # ascending order
        else
          b1 <=> a1 # descending order
        end
      elsif a2 != b2 then
        if (parsed and parsed["scoreboard"] and 
            parsed["scoreboard"].size > 2 and 
            parsed["scoreboard"][2]["asc"]) then
          a2 <=> b2 # ascending order
        else
          b2 <=> a2 # descending order
        end
      else
        a[:time] <=> b[:time]  # ascending by submission time
      end
    end
  end


  # 
  # createScoreboardEntry - Create a row in the scoreboard. If the
  # JSON autoresult string has a scoreboard array object, then use
  # that as the template, otherwise use the default, which is the
  # total score followed by the sum of the individual problem
  # scores.
  # 
  # Lab authors can override this function in the lab config file.
  #
  def createScoreboardEntry(scores, autoresult)
    
    # If the assessment was not autograded or the scoreboard was
    # not customized, then simply return the list of problem
    # scores and their total.
    if (!autoresult or 
        !@scoreboard_prop or
        !@scoreboard_prop.colspec or 
        @scoreboard_prop.colspec.blank?) then

      # First we need to get the total score
      total = 0.0;
      for problem in @assessment.problems do
        total += scores[problem.name].to_f
      end

      # Now build the array of scores
      entry = []
      entry << total.round(1).to_s
      for problem in @assessment.problems do
        entry << scores[problem.name]
      end
      return entry
    end

    # At this point we have an autograded assessment with a
    # customized scoreboard. Extract the scoreboard entry
    # from the scoreboard array object in the JSON autoresult.
    begin
      parsed = ActiveSupport::JSON.decode(autoresult)
      raise if !parsed or !parsed["scoreboard"] 
    rescue Exception=>e
      # If there is no autoresult for this student (typically
      # because their code did not compile or it segfaulted and
      # the intructor's autograder did not catch it) then
      # return a nicely formatted nil result.
      begin 
        parsed = ActiveSupport::JSON.decode(@scoreboard_prop.colspec)
        raise if !parsed or !parsed["scoreboard"]
        entry = []
        for item in parsed["scoreboard"] do
          entry << "-"
        end
        return entry
      rescue
        # Give up and bail
        return ["-"]
      end
    end

    # Found a valid scoreboard array, so simply return it. If we
    # wanted to be really careful, we would verify that the size
    # was the same size as the column specification.
    return parsed["scoreboard"]
  end

  #
  # scoreboardHeader - Build a scoreboard header string. 
  # 
  # For backward compatibility, this function can be overridden in
  # the config file.
  #
  def scoreboardHeader
    # If no submissions yet, then don't display the table
    if @grades.values.empty? then
      return "<h3>No submissions yet.</h3>"
    end
    
    # Grab the scoreboard properties for this assessment
    @scoreboard_prop = ScoreboardSetup.where(:assessment_id => @assessment.id).first

    # Determine which banner to use in the header
    banner = "<h3>Here are the most recent scores for the class.</h3>"
    if @scoreboard_prop and !@scoreboard_prop.banner.blank? then
      banner = "<h3>" + @scoreboard_prop.banner + "</h3>"
    end

    # If the lab is not autograded, or the columns property is not
    # specified, then return the default header.
    if (!@assessment.has_autograde or
        !@scoreboard_prop or @scoreboard_prop.colspec.blank?) then
      head =	banner + "<table class='sortable prettyBorder'> 
			<tr><th>Nickname</th><th>Version</th><th>Time</th>"
      head += "<th>Total</th>"
      for problem in @assessment.problems do
        head += "<th>" + problem.name + "</th>"
      end
      return head
    end

    # At this point, we know we have an autograded lab with a
    # non-empty column spec. Parse the spec and then return the
    # customized header.
    parsed = ActiveSupport::JSON.decode(@scoreboard_prop.colspec)
    head =	banner + "<table class='sortable prettyBorder'> 
			<tr><th>Nickname</th><th>Version</th><th>Time</th>"
    for object in parsed["scoreboard"] do
      head += "<th>" + object["hdr"] + "</th>"
    end
    head += '</tr>'
    return head
  end

  # get_props - Helper function that loads the persistent assessment
  # properties from a yaml file and returns a hash of the properties 
  def get_props
    filename = File.join(Rails.root, "courses", @course.name, 
               @assessment.name, "#{@assessment.name}.yml") 
    props = {}
    if File.exists?(filename) and File.readable?(filename) then
      f = File.open(filename, 'r')
      props = YAML.load(f.read)
      f.close
    end

    if props["general"].has_key?("handout_filename")
      props["general"]["handout"] = props["general"]["handout_filename"]
      props["general"].delete("handout_filename")
    end

    if props["general"].has_key?("writeup_filename")
      props["general"]["writeup"] = props["general"]["writeup_filename"]
      props["general"].delete("writeup_filename")
    end
    
    return props
  end

  def get_assessment
    @assessment = Assessment.find params[:assessment_id] || params[:id]
    @course = @assessment.course

    if ((!@cud.user.administrator?) && (@cud.course_id != @assessment.course_id)) then 
      flash[:error] = "You do not have permission to access this submission"
      redirect_to home_error_path and return
    end

    unless @assessment
      flash[:error] = "Sorry! we couldn't load the assessment \"#{assign}\""
      redirect_to home_error_path and return
    end
  end

  def extend_config_module
    begin
      require @assessment.config_file_path
      assessmentInitialize @assessment.name
      

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
          print nonmodule_func
          module_function(nonmodule_func)
          public nonmodule_func
        }
      end

    rescue Exception => @error
      # printing the error so that the bugs are traceable
      puts @error
      COURSE_LOGGER.log(@error)

      if @cud and @cud.has_auth_level? :instructor
        redirect_to action: :reload and return
      else
        redirect_to home_error_path and return
       end
    end
  end

  def releaseMatchingGrades
    num_released = 0

    @assessment.problems.each do |problem|
      @assessment.submissions.find_each do |sub|
        next unless yield(sub, problem)

        score = problem.scores.where(:submission_id => sub.id).first

        # if score already exists and isn't released, release it
        if score
          unless score.released
            score.released = true
            num_released += 1
          end

        # if score doesn't exist yet, create it and release it
        else
          score = problem.scores.new({
            :submission => sub,
            :released => true,
            :grader => @cud
          })
          num_released += 1
        end

        updateScore(sub.course_user_datum_id, score)
      end
    end
  
    num_released
  end

  # AutogradingSetup parameters for adminAutograde
  def autograde_prop_params
    params[:autograde_prop].permit(:assessment_id, :autograde_timeout, :autograde_image, :release_score)
  end
  
  def scoreboard_prop_params
    params[:scoreboard_prop].permit(:banner, :colspec)
  end

  private
  
    def new_assessment_params
      params.require(:assessment).permit(:name, :category_id)
    end

    # getCategoryList -  Helper that returns a hash of category->id pairs
    def getCategoryList
      categoryDump = @course.assessment_categories
      categories = {}
      for cat in categoryDump do
        categories[cat.name] = cat.id
      end
      return categories
    end
end
