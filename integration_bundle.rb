]633;C]633;E;for f in app/controllers/courses_controller.rb app/controllers/assessments_controller.rb app/controllers/assessment/handin*.rb app/controllers/file_manager_controller.rb app/models/course.rb\x3b do echo "===== $f ====="\x3b cat "$f"\x3b echo\x3b done > integration_bundle.rb;902748e1-8cd1-445b-bb93-3f17417e0660===== app/controllers/courses_controller.rb =====
require "archive"
require "csv"
require "fileutils"
require "pathname"
require "statistics"

class CoursesController < ApplicationController
  skip_before_action :set_course,
                     only: %i[courses_redirect index new create create_from_tar join_course]
  # you need to be able to pick a course to be authorized for it
  skip_before_action :authorize_user_for_course,
                     only: %i[courses_redirect index new create create_from_tar join_course]
  # if there's no course, there are no persistent announcements for that course
  skip_before_action :update_persistent_announcements,
                     only: %i[courses_redirect index new create create_from_tar join_course]
  before_action :set_manage_course_breadcrumb, only: %i[edit users moss email upload_roster export]
  before_action :set_manage_course_users_breadcrumb, only: %i[upload_roster]

  def index
    courses_for_user = User.courses_for_user current_user

    redirect_to(home_no_user_path) && return unless courses_for_user.any?

    @listing = categorize_courses_for_listing courses_for_user
  end

  def courses_redirect
    courses_for_user = User.courses_for_user current_user
    redirect_to(home_no_user_path) && return unless courses_for_user.any?

    @listing = categorize_courses_for_listing courses_for_user
    # if only enrolled in one course (currently), go to that course
    # only happens when first loading the site, not when user goes back to courses
    if @listing[:current].one?
      course_name = @listing[:current][0].name
      redirect_to course_assessments_url(course_name)
    else
      redirect_to(action: :index)
    end
  end

  def join_course
    return unless params[:access_code]

    # GET + access_code when using direct join link
    # POST + access_code when using join course form

    access_code = params[:access_code].upcase
    unless Course::VALID_CODE_REGEX.match?(access_code)
      flash[:error] = "Invalid access code format"
      redirect_to(join_course_courses_path) && return
    end

    course = Course.find_by(access_code:)
    if course.nil?
      flash[:error] = "Invalid access code"
      redirect_to(join_course_courses_path) && return
    end

    cud = course.course_user_data.find_by(user_id: current_user.id)

    if cud.nil?
      cud = course.course_user_data.new
      cud.user = current_user
      unless cud.save
        flash[:error] = "An error occurred while joining the course"
        redirect_to(join_course_courses_path) && return
      end
      # else, no point setting a flash because they will be redirected
      # to set their nickname
    else
      flash[:success] = "You are already enrolled in this course"
    end

    redirect_to course_path(course)
  end

  action_auth_level :show, :student
  def show
    redirect_to course_assessments_url(@course)
  end

  ROSTER_COLUMNS_S15 = 29
  ROSTER_COLUMNS_F16 = 32
  ROSTER_COLUMNS_F20 = 34

  action_auth_level :manage, :instructor
  def manage
    matrix = GradeMatrix.new @course, @cud
    cols = {}
    # extract assessment final scores
    @course.assessments.each do |asmt|
      next unless matrix.has_assessment? asmt.id

      cells = matrix.cells_for_assessment asmt.id
      final_scores = cells.map { |c| c["final_score"] }
      cols[asmt.name] = ["asmt", asmt, final_scores]
    end

    # category averages
    @course.assessment_categories.each do |cat|
      next unless matrix.has_category? cat

      cols["#{cat} Average"] = ["avg", nil, matrix.averages_for_category(cat)]
    end

    # course averages
    cols["Course Average"] = ["avg", nil, matrix.course_averages]

    # calculate statistics
    # send course_stats back in the form of
    # name of average / assesment -> [type, asmt, statistics]
    # where type = "asmt" or "avg" (assessment or average)
    # asmt = assessment object or nil if an average of category / class
    # statistics (statistics pertaining to asmt/avg (mean, median, std dev, etc))
    @course_stats = {}
    stat = Statistics.new
    cols.each do |key, values|
      @course_stats[key] = [values[0], values[1], stat.stats(values[2])]
    end
  end

  action_auth_level :new, :administrator
  def new
    # check for permission
    unless current_user.administrator?
      flash[:error] = "Permission denied."
      redirect_to(root_path) && return
    end
    @newCourse = Course.new
    @newCourse.late_penalty = Penalty.new
    @newCourse.version_penalty = Penalty.new
  end

  def create
    # check for permission
    unless current_user.administrator?
      flash[:error] = "Permission denied."
      redirect_to(root_path) && return
    end

    @newCourse = Course.new(new_course_params)

    @newCourse.display_name = @newCourse.name

    # fill temporary values in other fields
    @newCourse.late_slack = 0
    @newCourse.grace_days = 0
    @newCourse.start_date = Time.zone.now
    @newCourse.end_date = Time.zone.now

    @newCourse.late_penalty = Penalty.new
    @newCourse.late_penalty.kind = "points"
    @newCourse.late_penalty.value = "0"

    @newCourse.version_penalty = Penalty.new
    @newCourse.version_penalty.kind = "points"
    @newCourse.version_penalty.value = "0"

    if @newCourse.save
      instructor = User.where(email: params[:instructor_email]).first

      # create a new user as instructor if he didn't exist
      if instructor.nil?
        begin
          instructor = User.instructor_create(params[:instructor_email],
                                              @newCourse.name)
        rescue StandardError => e
          # roll back course creation
          @newCourse.destroy
          flash.now[:error] = "Can't create instructor for the course: #{e}"
          render(action: "new") && return
        end

      end

      new_cud = @newCourse.course_user_data.new
      new_cud.user = instructor
      new_cud.instructor = true

      if new_cud.save
        begin
          @newCourse.reload_course_config
        rescue StandardError, SyntaxError
          # roll back course creation and instruction creation
          new_cud.destroy
          @newCourse.destroy
          flash.now[:error] = "Can't load course config for #{@newCourse.name}."
          render(action: "new") && return
        else
          flash[:success] = "New Course #{@newCourse.name} successfully created!"
          redirect_to(edit_course_path(@newCourse)) && return
        end
      else
        # roll back course creation
        @newCourse.destroy
        flash.now[:error] = "Can't create instructor for the course."
        render(action: "new") && return
      end

    else
      flash.now[:error] = "Course creation failed. Please review the fields below."
      render(action: "new") && return
    end
  end

  action_auth_level :create_from_tar, :administrator
  def create_from_tar
    tarFile = params[:tarFile]
    if tarFile.nil?
      flash[:error] = "Please select a course tarball for uploading."
      render(action: "new") && return
    end

    begin
      tarFile = File.new(tarFile.open, "rb")
      tar_extract = Gem::Package::TarReader.new(tarFile)
      tar_extract.rewind
      unless valid_course_tar(tar_extract)
        flash[:error] +=
          "<br>Invalid tarball. A valid course tar has a single root "\
            "directory that's named after the course, containing a "\
            "course yaml file"
        flash[:html_safe] = true
        render(action: "new") && return
      end
      tar_extract.close
    rescue SyntaxError => e
      flash[:error] = "Error parsing course configuration file:"
      # escape so that <compiled> doesn't get treated as a html tag
      flash[:error] += "<br><pre>#{CGI.escapeHTML e.to_s}</pre>"
      flash[:html_safe] = true
      render(action: "new") && return
    rescue StandardError => e
      flash[:error] = "Error while reading the tarball -- #{e.message}."
      render(action: "new") && return
    end

    begin
      tar_extract.rewind
      @newCourse = get_course_from_config(tar_extract)
      # save assessment directories
      save_assessments_from_tar(tar_extract)
      tar_extract.close
    rescue StandardError => e
      flash[:error] = "Error while extracting course to server -- #{e.message}."
      render(action: "new") && return
    end

    unless @newCourse.save
      flash[:error] = "Course creation failed. Please review all fields below."
      render(action: "new") && return
    end

    instructor = User.where(email: params[:instructor_email]).first

    # create a new user as instructor if they didn't exist
    if instructor.nil?
      begin
        instructor = User.instructor_create(params[:instructor_email],
                                            @newCourse.name)
      rescue StandardError => e
        # roll back course creation
        @newCourse.destroy
        flash[:error] = "Can't create instructor for the course: #{e}"
        render(action: "new") && return
      end
    end

    new_cud = @newCourse.course_user_data.new
    new_cud.user = instructor
    new_cud.instructor = true

    unless new_cud.save
      # roll back course creation
      @newCourse.destroy
      flash[:error] = "Can't create instructor for the course."
      render(action: "new") && return
    end

    begin
      @newCourse.reload_course_config
    rescue StandardError, SyntaxError
      # roll back course creation and instruction creation
      new_cud.destroy
      @newCourse.destroy
      flash[:error] = "Can't load course config for #{@newCourse.name}."
      render(action: "new") && return
    else
      flash[:success] = "New Course #{@newCourse.name} successfully created!"
      redirect_to(course_onboard_install_asmt_course_assessments_path(@newCourse)) && return
    end
  end

  action_auth_level :edit, :instructor
  def edit; end

  action_auth_level :update, :instructor
  def update
    uploaded_config_file = params[:editCourse][:config_file]
    unless uploaded_config_file.nil?
      config_source = uploaded_config_file.read

      course_config_source_path = @course.source_config_file_path
      File.open(course_config_source_path, "w") do |f|
        f.write(config_source)
      end
      FilesystemEnforcer.fix_path(course_config_source_path.to_s)

      begin
        @course.reload_course_config
      rescue StandardError, SyntaxError => e
        @error = e
        render("reload") && return
      end
    end

    if @course.update(edit_course_params)
      flash[:success] = "Course configuration updated!"
    else
      flash[:error] = "Error: There were errors editing the course."
      @course.errors.full_messages.each do |msg|
        flash[:error] += "<br>#{msg}"
      end
      flash[:html_safe] = true
    end
    redirect_to edit_course_path(@course)
  end

  # DELETE courses/:id/
  action_auth_level :destroy, :administrator
  def destroy
    # Delete config file copy in courseConfig
    if File.exist? @course.config_file_path
      File.delete @course.config_file_path
    end
    if File.exist? @course.config_backup_file_path
      File.delete @course.config_backup_file_path
    end

    if @course.destroy
      flash[:success] = "Course destroyed."
    else
      flash[:error] = "Error: Course wasn't destroyed!"
    end
    redirect_to(courses_path) && return
  end

  # Non-RESTful Routes Below

  def report_bug
    return unless request.post?

    CourseMailer.bug_report(
      params[:title],
      params[:summary],
      current_user,
      @course
    ).deliver
  end

  # Only instructor (and above) can use this feature
  # to look up user accounts and fill in cud fields
  action_auth_level :user_lookup, :instructor
  def user_lookup
    if params[:email].empty?
      flash[:error] = "No email supplied for LDAP Lookup"
      render(action: :new, layout: false) && return
    end

    # make sure that user already exists in the database
    user = User.where(email: params[:email]).first

    render(json: nil) && return if user.nil?

    @user_data = { first_name: user.first_name,
                   last_name: user.last_name,
                   email: user.email }

    render json: @user_data
  end

  action_auth_level :users, :instructor
  def users
    @cuds = if params[:search]
              # left over from when AJAX was used to find users on the admin users list
              @course.course_user_data.joins(:user)
                     .order("users.email ASC")
                     .where(CourseUserDatum
                                .conditions_by_like(params[:search]))
            else
              @course.course_user_data.joins(:user).order("users.email ASC")
            end
  end

  action_auth_level :add_users_from_emails, :instructor
  def add_users_from_emails
    # check if user_emails and role exist in params
    unless params.key?(:user_emails) && params.key?(:role)
      flash[:error] = "No user emails or role supplied"
      redirect_to(users_course_path(@course)) && return
    end

    user_emails = params[:user_emails].split(/\n/).map(&:strip)

    user_emails = user_emails.map do |email|
      if email.nil?
        nil
        # when it's first name <email>
      elsif email =~ /(.*)\s+(.*)\s+(.*)\s+<(.*)>/
        { first_name: Regexp.last_match(1), middle_name: Regexp.last_match(2),
          last_name: Regexp.last_match(3), email: Regexp.last_match(4) }
        # when it's email
      elsif email =~ /(.*)\s+(.*)\s+<(.*)>/
        { first_name: Regexp.last_match(1), last_name: Regexp.last_match(2),
          email: Regexp.last_match(3) }
        # when it's first name middle name last name <email>
      elsif email =~ /(.*)\s+<(.*)>/
        { first_name: Regexp.last_match(1), email: Regexp.last_match(2) }
        # when it's first name last name <email>
      else
        { email: }
      end
    end

    # filter out nil emails
    user_emails = user_emails.reject(&:nil?)

    # check if email matches regex
    email_regex = /\A[\w+\-.]+@[a-z\d-]+(\.[a-z\d-]+)*\.[a-z]+\z/i

    # raise error if any email is invalid and return which emails are invalid
    invalid_emails = user_emails.reject { |user| user[:email] =~ email_regex }
    if invalid_emails.any?
      flash[:error] = "Invalid email(s): #{invalid_emails.map { |user| user[:email] }.join(', ')}"
      redirect_to([:users, @course]) && return
    end

    role = params[:role]

    @cuds = []
    user_emails.each do |email|
      user = User.find_by(email: email[:email])

      # create users if they don't exist
      if user.nil?
        begin
          user = if email[:first_name].nil? && email[:last_name].nil?
                   User.roster_create(email[:email], email[:email], "", "", "", "")
                 else
                   User.roster_create(email[:email], email[:first_name] || "",
                                      email[:last_name] || "", "", "", "")
                 end
        rescue StandardError => e
          flash[:error] = "Error: #{e.message}"
          redirect_to([:users, @course]) && return
        end

        if user.nil?
          flash[:error] = "Error: User #{email} could not be created."
          redirect_to([:users, @course]) && return
        end
      end

      # if user already exists in the course, retrieve the cud
      cud = @course.course_user_data.find_by(user_id: user.id)

      # if user doesn't exist in the course, create a new cud
      if cud.nil?
        cud = @course.course_user_data.new
        cud.user = user
      end

      # set the role of the user
      case role
      when "instructor"
        cud.instructor = true
        cud.course_assistant = false
      when "ca"
        cud.instructor = false
        cud.course_assistant = true
      when "student"
        cud.instructor = false
        cud.course_assistant = false
      # if role is not valid, return error
      else
        flash[:error] = "Error: Invalid role #{role}."
        redirect_to([:users, @course]) && return
      end

      # add the cud to the list of cuds to be saved
      @cuds << cud
    end

    # save all the cuds
    if @cuds.all?(&:save)
      flash[:success] = "Success: Users added to course."
    else
      flash[:error] = "Error: Users could not be added to course."
    end
    redirect_to([:users, @course]) && return
  end

  action_auth_level :unlink_course, :instructor
  def unlink_course
    lcd = LtiCourseDatum.find_by(course_id: @course.id)

    if lcd.nil?
      flash[:error] = "Unable to unlink course"
      redirect_to(action: :users) && return
    end

    lcd.destroy
    flash[:success] = "Course unlinked"
    redirect_to(action: :users) && return
  end

  action_auth_level :update_lti_settings, :instructor
  def update_lti_settings
    lcd = @course.lti_course_datum
    lcd.drop_missing_students = params[:lcd][:drop_missing_students] == "1"
    lcd.save

    redirect_to(action: :users) && return
  end

  action_auth_level :reload, :instructor
  def reload
    @course.reload_course_config
  rescue StandardError, SyntaxError => e
    @error = e
    # let the reload view render
  else
    flash[:success] = "Success: Course config file reloaded!"
    redirect_to([@course]) && return
  end

  # Upload a CSV roster and import the users into the course
  # Colors are associated to each row of CUD after roster is processed:
  #   green - User doesn't exist in the course, and is going to be added
  #   red - User is going to be dropped from the course
  #   black - User exists in the course
  action_auth_level :upload_roster, :instructor
  def upload_roster
    return unless request.post?

    # Check if any file is attached
    if params["upload"] && params["upload"]["file"].nil?
      flash[:error] = "Please attach a roster!"
      redirect_to(action: :upload_roster) && return
    end

    if params[:doIt]
      begin
        save_uploaded_roster
        flash[:success] = "Successfully updated roster!"
        unless @roster_warnings.nil?
          w = "Warning: #{@roster_warnings.keys.join(', ')}"
          flash[:error] = w
        end
        redirect_to(action: "users") && return
      rescue StandardError => e
        if e != "Roster validation error"
          flash[:error] = e
        end
        redirect_to(action: "upload_roster") && return
      end
    else
      parse_roster_csv
    end
  end

  action_auth_level :download_roster, :instructor
  def download_roster
    @cuds = @course.course_user_data.where(instructor: false,
                                           course_assistant: false,
                                           dropped: false)
    csv_content = CSVSafe.generate do |csv|
      @cuds.each do |cud|
        user = cud.user
        # to_csv avoids issues with commas
        csv << [@course.semester, cud.user.email, user.last_name, user.first_name,
                cud.school, cud.major, cud.year, cud.grade_policy,
                cud.course_number, cud.lecture, cud.section]
      end
    end
    send_data csv_content, filename: "roster.csv", type: "text/csv", disposition: "inline"
  end

  # email - The email action allows instructors to email the entire course, or
  # a single section at a time.  Sections are passed via params[:section].
  action_auth_level :email, :instructor
  def email
    return unless request.post?

    section = (params[:section] if !params[:section].empty?)

    # don't email kids who dropped!
    @cuds = if section
              @course.course_user_data.where(dropped: false, section:)
            else
              @course.course_user_data.where(dropped: false)
            end

    bccString = make_dlist(@cuds)

    @email = CourseMailer.course_announcement(
      params[:from],
      bccString,
      params[:subject],
      params[:body],
      @cud,
      @course
    )
    @email.deliver
  end

  action_auth_level :moss, :instructor
  def moss
    @courses = if @cud.user.administrator?
                 Course.all
               else
                 Course.joins(:course_user_data)
                       .where(course_user_data: { user_id: @cud.user.id, instructor: true })
               end
  end

  LANGUAGE_WHITELIST = %w[c cc java ml pascal ada lisp scheme haskell fortran ascii vhdl perl
                          matlab python mips prolog spice vb csharp modula2 a8086 javascript plsql
                          verilog].freeze

  action_auth_level :run_moss, :instructor
  def run_moss
    # Return if we have no files to process.
    unless params[:assessments] || params[:external_tar]
      flash[:error] = "No input files provided for MOSS."
      redirect_to(action: :moss) && return
    end
    assessmentIDs = params[:assessments]
    assessments = []

    # First, validate access on each of the requested assessments
    assessmentIDs&.keys&.each do |aid|
      assessment = Assessment.find_by(id: aid)
      unless assessment
        flash[:error] = "Invalid Assessment ID: #{aid}"
        redirect_to(action: :moss) && return
      end
      assessmentCUD = assessment.course.course_user_data.joins(:user).find_by(
        users: { email: current_user.email }, instructor: true
      )
      if !assessmentCUD && !@cud.user.administrator?
        flash[:error] = "Invalid User"
        redirect_to(action: :moss) && return
      end
      assessments << assessment
    end

    # Create a temporary directory
    @failures = []
    tmp_dir = Dir.mktmpdir("#{@cud.user.email}Moss", Rails.root.join("tmp"))

    files = params[:files]
    base_file = params[:box_basefile]
    max_lines = params[:box_max]
    language = params[:box_language]

    moss_params = ""
    files&.each do |_, v|
      # Space-separated patterns
      patternList = v.split(" ")
      # Each pattern consists of one or more segments, where each segment consists of
      # - a leading period (optional)
      # - a word character (A..Z, a..z, 0..9, _), or hyphen (-), or asterisk (*)
      # Each pattern optionally ends with a period
      # OKAY: foo.c *.c * .c README foo_c foo-c .* **
      # NOT OKAY: . ..
      patternList.each do |pattern|
        unless pattern =~ /\A(\.?[\w*-])+\.?\z/
          flash[:error] = "Invalid file pattern"
          redirect_to(action: :moss) && return
        end
      end
    end
    unless base_file.nil?
      extract_tar_for_moss(tmp_dir, params[:base_tar], false)
      moss_params = [moss_params, "-b", @basefiles].join(" ")
    end
    unless max_lines.nil?
      params[:max_lines] = 10 if params[:max_lines] == ""
      # Only accept positive integers (> 0)
      unless params[:max_lines] =~ /\A[1-9]([0-9]*)?\z/
        flash[:error] = "Invalid max lines"
        redirect_to(action: :moss) && return
      end
      moss_params = [moss_params, "-m", params[:max_lines]].join(" ")
    end
    unless language.nil?
      unless LANGUAGE_WHITELIST.include? params[:language_selection]
        flash[:error] = "Invalid language"
        redirect_to(action: :moss) && return
      end
      moss_params = [moss_params, "-l", params[:language_selection]].join(" ")
    end

    # Get moss flags from text field
    moss_flags = ["mossnet#{moss_params} -d"].join(" ")
    @mossCmd = [Rails.root.join("vendor", moss_flags)]

    extract_asmt_for_moss(tmp_dir, assessments)
    extract_tar_for_moss(tmp_dir, params[:external_tar], true)

    # Ensure that all files in Moss tmp dir are readable
    system("chmod -R a+r #{tmp_dir}")
    ActiveRecord::Base.clear_active_connections!
    # Remove non text files when making a moss run
    Dir.chdir(Rails.root.join("script")) do
      system("./cleanMoss #{tmp_dir}")
    end
    # Now run the Moss command
    @mossCmdString = @mossCmd.join(" ")
    @mossOutput = `#{@mossCmdString} 2>&1`
    @mossExit = $?.exitstatus

    # Clean up after ourselves (droh: leave for debugging)
    `rm -rf #{tmp_dir}`
  end

  action_auth_level :export, :instructor
  def export; end

  action_auth_level :export_selected, :instructor
  def export_selected
    tar_stream = @course.generate_tar(params[:export_configs])

    send_data tar_stream.string.force_encoding("binary"),
              filename: "#{@course.name}_#{Time.current.strftime('%Y%m%d')}.tar",
              type: "application/x-tar",
              disposition: 'attachment'
  rescue SystemCallError => e
    flash[:error] = "Unable to create the config YAML file: #{e.message}"
    redirect_to(action: :export)
  rescue StandardError => e
    flash[:error] = "Unable to generate tarball -- #{e.message}"
    redirect_to(action: :export)
  end

private

  def new_course_params
    params.require(:newCourse).permit(:name, :semester)
  end

  def edit_course_params
    att = params.require(:editCourse).permit(:semester, :website, :late_slack,
                                             :grace_days, :display_name, :start_date, :end_date,
                                             :disabled, :exam_in_progress, :allow_self_enrollment,
                                             :version_threshold, :gb_message, :disable_on_end,
                                             late_penalty_attributes: %i[kind value],
                                             version_penalty_attributes: %i[kind value])

    handle_self_enrollment(att)
  end

  def handle_self_enrollment(att)
    if params[:allow_self_enrollment] && @course.access_code.blank?
      att.merge!(access_code: generate_access_code)
    elsif !params[:allow_self_enrollment]
      att.merge!(access_code: nil)
    end
    att.except(:allow_self_enrollment)
  end

  def generate_access_code
    loop do
      code = SecureRandom.alphanumeric(6).upcase

      # Possible race condition, but we also have a uniqueness validation
      break code unless Course.where(access_code: code).exists?
    end
  end

  def categorize_courses_for_listing(courses)
    listing = {}

    # temporal
    listing[:current] = []
    listing[:completed] = []
    listing[:upcoming] = []

    listing[:disabled] = []
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

  def write_cuds(cuds)
    rowNum = 0
    rosterErrors = {}
    rosterWarnings = {}
    rowCUDs = []
    duplicates = Set.new

    cuds.each do |new_cud|
      cloneCUD = new_cud.clone
      cloneCUD[:row_num] = rowNum + 2
      rowCUDs.push(cloneCUD)

      case new_cud[:color]
      when "green"
        # Add this user to the course
        # Look for this user
        email = new_cud[:email]
        first_name = new_cud[:first_name]
        last_name = new_cud[:last_name]
        school = new_cud[:school]
        major = new_cud[:major]
        year = new_cud[:year]

        if (user = User.where(email:).first).nil?
          begin
            # Create a new user
            user = User.roster_create(email, first_name, last_name, school,
                                      major, year)
          rescue StandardError => e
            msg = "#{e} at line #{rowNum + 2} of the CSV"
            if !rosterErrors.key?(msg)
              rosterErrors[msg] = []
            end
            rosterErrors[msg].push(cloneCUD)
          end
        else
          # Override current user
          user.first_name = first_name
          user.last_name = last_name
          user.school = school
          user.major = major
          user.year = year
          begin
            user.save!
          rescue StandardError => e
            msg = "#{e} at line #{rowNum + 2} of the CSV"
            if !rosterErrors.key?(msg)
              rosterErrors[msg] = []
            end
            rosterErrors[msg].push(cloneCUD)
          end
        end

        existing = @course.course_user_data.where(user:).first
        # Make sure this user doesn't have a cud in the course
        if existing
          duplicates.add(new_cud[:email])
        end

        # Delete unneeded data
        new_cud.delete(:color)
        new_cud.delete(:email)
        new_cud.delete(:first_name)
        new_cud.delete(:last_name)
        new_cud.delete(:school)
        new_cud.delete(:major)
        new_cud.delete(:year)

        # Build cud
        if !user.nil? && !existing
          cud = @course.course_user_data.new
          cud.user = user
          params = ActionController::Parameters.new(
            course_number: new_cud[:course_number],
            lecture: new_cud[:lecture],
            section: new_cud[:section],
            grade_policy: new_cud[:grade_policy]
          )
          cud.assign_attributes(params.permit(:course_number, :lecture, :section, :grade_policy))

          # Save without validations
          cud.save(validate: false)
        end

      when "red"
        # Drop this user from the course
        existing = @course.course_user_data.includes(:user)
                          .where(users: { email: new_cud[:email] }).first

        fail "Red CUD doesn't exist in the database." if existing.nil?

        existing.dropped = true
        existing.save(validate: false)
      else
        # Update this user's attributes.
        existing = @course.course_user_data.includes(:user)
                          .where("lower(users.email) = ?", new_cud[:email].downcase)
                          .references(:users).first
        # existing = @course.course_user_data.includes(:user).
        # where(users[:email].matches("%#{new_cud[:email]}%")).first

        fail "Black CUD doesn't exist in the database." if existing.nil?

        user = existing.user
        if user.nil?
          fail "User associated to black CUD doesn't exist in the database."
        end

        # Update user data
        user.first_name = new_cud[:first_name]
        user.last_name = new_cud[:last_name]
        user.school = new_cud[:school]
        user.major = new_cud[:major]
        user.year = new_cud[:year]

        begin
          user.save!
        rescue StandardError => e
          msg = "#{e} at line #{rowNum + 2} of the CSV"
          if !rosterErrors.key?(msg)
            rosterErrors[msg] = []
          end
          rosterErrors[msg].push(cloneCUD)
        end

        # Delete unneeded data
        new_cud.delete(:color)
        new_cud.delete(:email)
        new_cud.delete(:first_name)
        new_cud.delete(:last_name)
        new_cud.delete(:school)
        new_cud.delete(:major)
        new_cud.delete(:year)

        # assign attributes
        params = ActionController::Parameters.new(
          course_number: new_cud[:course_number],
          lecture: new_cud[:lecture],
          section: new_cud[:section],
          grade_policy: new_cud[:grade_policy]
        )
        existing.assign_attributes(params.permit(:course_number, :lecture, :section, :grade_policy))
        existing.dropped = false
        existing.save(validate: false) # Save without validations.
      end
      rowNum += 1
    end

    rowCUDs.each_with_index do |cud, line|
      next unless duplicates.include?(cud[:email])

      msg = "#{cud[:email]} is a duplicate email at line #{line}"
      if !rosterWarnings.key?(msg)
        rosterWarnings[msg] = []
      end
      rosterWarnings[msg].push(cud)
    end

    @roster_warnings = rosterWarnings

    return if rosterErrors.empty?

    @roster_error = rosterErrors
    fail "Roster validation error"
  end

  def save_uploaded_roster
    cuds = []

    rowNum = 0
    until params["cuds"][rowNum.to_s].nil?
      cuds.push(params["cuds"][rowNum.to_s])
      rowNum += 1
    end

    CourseUserDatum.transaction do
      write_cuds(cuds)
    end
  end

  def change_view(is_sorted)
    @cud_view = if is_sorted
                  @sorted_cuds
                else
                  @cuds
                end
  end

  def parse_roster_csv
    # generate doIt form from the upload
    @cuds = []
    @currentCUDs = @course.course_user_data.all.to_a
    @new_cuds = []

    begin
      csv = detect_and_convert_roster(params["upload"]["file"].read)
      csv.each do |row|
        new_cud = { # Ignore Semester (row[0])
          email: row[1].to_s,
          last_name: row[2].to_s.chomp(" "),
          first_name: row[3].to_s.chomp(" "),
          school: row[4].to_s.chomp(" "),
          major: row[5].to_s.chomp(" "),
          year: row[6].to_s.chomp(" "),
          grade_policy: row[7].to_s.chomp(" "),
          course_number: row[8].to_s.chomp(" "),
          lecture: row[9].to_s.chomp(" "),
          section: row[10].to_s.chomp(" ")
        }
        cud = @currentCUDs.find do |current|
          current.user && current.user.email.downcase == new_cud[:email].downcase
        end

        if !cud
          new_cud[:color] = "green"
        else
          @currentCUDs.delete(cud)
        end
        @cuds << new_cud
      end
    rescue CSV::MalformedCSVError => e
      flash[:error] = "Error parsing CSV file: #{e}"
      redirect_to(action: "upload_roster") && return
    rescue StandardError => e
      flash[:error] = "Error uploading the CSV file: #{e}"
      redirect_to(action: "upload_roster") && return
      raise e
    end

    # drop the rest if indicated
    if params[:upload][:dropMissing] == "1"
      # We never drop instructors, remove them first
      @currentCUDs.delete_if do |cud|
        cud.instructor? || cud.user.administrator? || cud.course_assistant?
      end
      @currentCUDs.each do |cud| # These are the drops
        new_cud = {
          email: cud.user.email,
          last_name: cud.user.last_name,
          first_name: cud.user.first_name,
          school: cud.school,
          major: cud.major,
          year: cud.year,
          grade_policy: cud.grade_policy,
          course_number: cud.course_number,
          lecture: cud.lecture,
          section: cud.section,
          color: "red"
        }
        @cuds << new_cud
      end
    end

    # do dry run for error checking
    CourseUserDatum.transaction do
      cloned_cuds = Marshal.load(Marshal.dump(@cuds))
      begin
        write_cuds(cloned_cuds)
        @sorted_cuds = @cuds.sort_by { |cud| cud[:color] || "z" }
        @cud_view = @sorted_cuds
      rescue StandardError
        # Renders upload_roster
        return
      ensure
        raise ActiveRecord::Rollback
      end
    end
  end

  # detect_and_convert_roster - Detect the type of a roster based on roster
  # column matching and convert to default roster

  # map fields:
  # map[0]: semester (unused)
  # map[1]: email
  # map[2]: last_name
  # map[3]: first_name
  # map[4]: school
  # map[5]: major
  # map[6]: year
  # map[7]: grade_policy
  # map[8]: course
  # map[9]: lecture
  # map[10]: section
  # rubocop:disable Lint/UselessAssignment
  def detect_and_convert_roster(roster)
    raise "Roster is empty" if roster.empty?

    parsedRoster = CSV.parse(roster, skip_blanks: true)
    raise "Roster cannot be recognized" if parsedRoster[0][0].nil?

    case parsedRoster[0].length
    when ROSTER_COLUMNS_F20 # 34 fields
      # In CMU S3 roster. Columns are:
      # Semester(0 - skip), Course(1), Section(2), Lecture(3), Mini(4 - skip),
      # Last Name(5), Preferred/First Name(6), MI(7 - skip), Andrew ID(8),
      # Email(9 - skip), College(10), Department(11 - skip), Major(12),
      # Class(13), Graduation Semester(14 - skip), Units(15 - skip), Grade Option(16)
      # ... the remaining fields are all skipped but shown for completeness
      # QPA Scale(17), Mid-Semester Grade(18), Primary Advisor(19), Final Grade(20),
      # Default Grade(21), Time Zone Code(22), Time Zone Description(23), Added By(24),
      # Added On(25), Confirmed(26), Waitlist Position(27), Units Carried/Max Units(28),
      # Waitlisted By(29), Waitlisted On(30), Dropped By(31), Dropped On(32), Roster As Of Date(33)
      map = [-1, 8, 5, 6, 10, 12, 13, 16, 1, 3, 2]
      select_columns = ROSTER_COLUMNS_F20
    when ROSTER_COLUMNS_F16 # 32 fields
      # In CMU S3 roster. Columns are:
      # Semester(0 - skip), Course(1), Section(2), Lecture(3), Mini(4 - skip),
      # Last Name(5), Preferred/First Name(6), MI(7 - skip), Andrew ID(8),
      # Email(9 - skip), College(10), Department(11), Major(12),
      # Class(13), Graduation Semester(14 - skip), Units(15 - skip), Grade Option(16)
      # ... the remaining fields are all skipped but shown for completeness
      # QPA Scale(17), Mid-Semester Grade(18), Primary Advisor(19), Final Grade(20),
      # Default Grade(21), Added By(22), Added On(23), Confirmed(24), Waitlist Position(25),
      # Units Carried/Max Units(26), Waitlisted By(27), Waitlisted On(28), Dropped By(29),
      # Dropped On(30), Roster As Of Date(31)
      map = [-1, 8, 5, 6, 10, 12, 13, 16, 1, 3, 2]
      select_columns = ROSTER_COLUMNS_F16
    when ROSTER_COLUMNS_S15 # 29 fields
      # In CMU S3 roster. Columns are:
      # Semester(0 - skip), Lecture(1), Section(2), (skip)(3), (skip)(4), Last Name(5),
      # First Name(6), (skip)(7), Andrew ID(8), (skip)(9), School(10),
      # Major(11), Year(12), (skip)(13), Grade Policy(14), ... [elided]
      map = [-1, 8, 5, 6, 10, 11, 12, 14, -1, 1, 2]
      select_columns = ROSTER_COLUMNS_S15
    else
      # No header row. Columns are:
      # Semester(0 - skip), Email(1), Last Name(2), First Name(3), School(4),
      # Major(5), Year(6), Grade Policy(7), Course(8), Lecture(9),
      # Section(10)
      return parsedRoster
    end
    # rubocop:enable Lint/UselessAssignment

    # Detect if there is a header row
    offset = if parsedRoster[0][0] == "Semester"
               1
             else
               0
             end
    numRows = parsedRoster.length - offset
    convertedRoster = Array.new(numRows) { Array.new(11) }

    domain = if Rails.env.production?
               "andrew.cmu.edu"
             else
               "foo.bar"
             end
    (0..(numRows - 1)).each do |i|
      11.times do |j|
        next unless map[j] >= 0

        convertedRoster[i][j] = if j == 1
                                  "#{parsedRoster[i + offset][map[j]]}@#{domain}"
                                else
                                  parsedRoster[i + offset][map[j]]
                                end
      end
    end
    convertedRoster
  end

  def extract_asmt_for_moss(tmp_dir, assessments)
    # for each assessment
    assessments.each do |ass|
      # Create a directory for ths assessment
      assDir = File.join(tmp_dir, "#{ass.name}-#{ass.course.name}")
      Dir.mkdir(assDir)

      # params[:isArchive] might be nil if no archive assessments are submitted
      isArchive = params[:isArchive] && params[:isArchive][ass.id.to_s]

      visitedGroups = Set.new

      # For each student who submitted
      ass.submissions.latest.each do |sub|
        subFile = sub.handin_file_path
        next unless subFile && File.exist?(subFile)

        if ass.has_groups?
          group_id = sub.aud.group_id
          next if visitedGroups.include?(group_id)

          visitedGroups.add(group_id)
        end

        # Create a directory for this student
        stuDir = File.join(assDir, sub.course_user_datum.email)
        Dir.mkdir(stuDir)

        # Copy their submission over
        FileUtils.cp(subFile, stuDir)
        FilesystemEnforcer.fix_path(File.join(stuDir, File.basename(subFile)))

        # Read archive files
        next unless isArchive

        # If we need to unarchive this file, then create archive reader
        archive_path = File.join(stuDir, sub.filename)
        begin
          archive_extract = Archive.get_archive(archive_path)

          archive_extract.each do |entry|
            pathname = Archive.get_entry_name(entry)
            next if Archive.looks_like_directory?(pathname)

            pathname.gsub!(%r{/}, "-")
            pathname.prepend("MOSS-")
            destination = File.join(stuDir, pathname)
            # make sure all subdirectories are there
            FileUtils.mkdir_p(File.dirname(destination))
            File.open(destination, "wb") do |out|
              out.write Archive.read_entry_file(entry)
              begin
                out.fsync
              rescue StandardError
                nil
              end
            end
          end
        rescue StandardError
          @failures << sub.filename
        end
      end

      # add this assessment to the moss command
      patternList = params["files"][ass.id.to_s].split(" ")
      patternList.each do |pattern|
        @mossCmd << File.join(assDir, ["*", pattern])
      end
    end
  end

  def extract_tar_for_moss(tmp_dir, external_tar, archive)
    return unless external_tar

    # Directory to hold tar ball and all individual files.
    extTarDir = File.join(tmp_dir, "external_input")
    baseFilesDir = File.join(tmp_dir, "basefiles")
    begin
      Dir.mkdir(extTarDir)
      Dir.mkdir(baseFilesDir) # To hold all basefiles
    rescue StandardError
      nil
    end

    # Read in the tarfile from the given source.
    extTarPath = File.join(extTarDir, "input_file")
    external_tar.rewind
    File.open(extTarPath, "wb") { |f| f.write(external_tar.read) } # Write tar file.
    FilesystemEnforcer.fix_path(extTarPath)

    # Directory to hold all external individual submission.
    extFilesDir = File.join(extTarDir, "submissions")

    begin
      Dir.mkdir(extFilesDir) # To hold all submissions
    rescue StandardError
      nil
    end

    # Untar the given Tar file.
    begin
      archive_extract = Archive.get_archive(extTarPath)

      # write each file, renaming nested files
      archive_extract.each do |entry|
        pathname = Archive.get_entry_name(entry)
        next if Archive.looks_like_directory?(pathname)

        output_dir = if archive
                       extFilesDir
                     else
                       baseFilesDir
                     end
        output_file = File.join(output_dir, pathname)

        # skip if the file lies outside the archive
        next unless Archive.in_dir?(Pathname(output_file), Pathname(output_dir))

        # make sure all subdirectories are there
        File.open(output_file, "wb") do |out|
          out.write Archive.read_entry_file(entry)
          begin
            out.fsync
          rescue StandardError
            nil
          end
        end
        FilesystemEnforcer.fix_path(output_file)
      end
    rescue StandardError
      @failures << "External Tar"
    end

    # Feed the uploaded files to MOSS.
    if archive
      @mossCmd << File.join(extFilesDir, "*")
    else
      @basefiles = File.join(baseFilesDir, "*")
    end
  end

  def get_course_from_config(tar_extract)
    tar_extract.rewind

    tar_extract.each do |entry|
      next unless entry.file? && entry.full_name.count('/') == 1
      # there should only be one file in the main directory with .yml extension
      next unless File.extname(entry.full_name) == '.yml'

      config = YAML.safe_load(entry.read, permitted_classes: [Date])
      general_config = config["general"]
      course = Course.new(general_config.except("late_penalty", "version_penalty"))
      course.late_penalty = Penalty.new(general_config["late_penalty"])
      course.version_penalty = Penalty.new(general_config["version_penalty"])

      # metrics import if exists in the file
      config["risk_conditions"]&.each do |condition|
        options = { course_id: course.id, condition_type: condition["condition_type"],
                    parameters: condition["parameters"].to_hash, version: condition["version"] }
        course.risk_conditions << RiskCondition.new(options)
      end

      if config["watchlist_configuration"]
        wl_config = config["watchlist_configuration"]
        course.watchlist_configuration = WatchlistConfiguration.new
        course.watchlist_configuration.category_blocklist = wl_config["category_blocklist"]
        course.watchlist_configuration.assessment_blocklist = wl_config["assessment_blocklist"]
        course.watchlist_configuration.allow_ca = wl_config["allow_ca"]
      end
      return course
    end
  end

  def save_assessments_from_tar(tar_extract)
    tar_extract.rewind
    src_directory = File.join(@newCourse.name, "assessments")
    dest_directory = Rails.root.join("courses", @newCourse.name)

    tar_extract.each do |entry|
      next unless File.dirname(entry.full_name).start_with?(src_directory)

      relative_path = entry.full_name.gsub(/\A#{Regexp.escape(src_directory)}/, '')
      destination_path = File.join(dest_directory, relative_path)
      if entry.directory?
        FileUtils.mkdir_p(destination_path)
      elsif entry.file?
        FileUtils.mkdir_p(File.dirname(destination_path))
        File.open(destination_path, 'wb') { |dest_file| dest_file.write(entry.read) }
      end
    end

    params[:cleanup_on_failure] = true
    FilesystemEnforcer.fix_tree(dest_directory.to_s)
  end

  # same as assessment import check, ensures the tar has a single root directory
  # named after the course with a course yml file
  def valid_course_tar(tar_extract)
    course_name = nil
    course_yml_exists = false
    course_name_is_valid = true
    tar_extract.each do |entry|
      pathname = entry.full_name
      next if pathname.start_with? "."

      # Removes file created by Mac when tar'ed
      next if pathname.start_with? "PaxHeader"

      pathname.chomp!("/") if entry.directory?
      # nested directories are okay
      if entry.directory? && pathname.count("/") == 0
        if course_name
          flash[:error] = "Error in tarball: Found root directory #{course_name}
                           but also found root directory #{pathname}. Ensure
                           there is only one root directory in the tarball."
          return false
        end

        course_name = pathname
      else
        if !course_name
          flash[:error] = "Error in tarball: No root directory found."
          return false
        end

        if pathname == "#{course_name}/course.rb"
          # We only ever read once, so no need to rewind after
          config_source = entry.read

          # validate syntax of config
          RubyVM::InstructionSequence.compile(config_source)
        end
        course_yml_exists = true if pathname == "#{course_name}/#{course_name}.yml"
      end
    end
    # it is possible that the course path does not match the
    # the expected course path when the Ruby config file
    # has a different name then the pathname
    if !course_name.nil? && course_name !~ /\A(\w|-)+\z/
      flash[:error] = "Errors found in tarball: Course name is invalid. Valid course names consist
                  of letters, numbers, and hyphens, starting and ending with a letter or number."
      return false
    end
    if !(course_yml_exists && !course_name.nil?)
      flash[:error] = "Errors found in tarball:"
      if !course_yml_exists && !course_name.nil?
        flash[:error] += "<br>Course yml file #{course_name}/#{course_name}.yml was not found"
      end
      flash[:html_safe] = true
    end
    course_yml_exists && !course_name.nil? && course_name_is_valid
  end
end

===== app/controllers/assessments_controller.rb =====
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

  # Manage submissions
  action_auth_level :excuse_popover, :course_assistant

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
          FilesystemEnforcer.fix_path(entry_file)
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
          FilesystemEnforcer.fix_path(entry_file)
        elsif entry.header.typeflag == "2"
          File.symlink entry.header.linkname, entry_file
        end
      end
      tar_extract.close
    FilesystemEnforcer.fix_tree(assessment_path.to_s)
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

  def excuse_popover
    submission_id = params[:submission_id]
    @submission = Submission.find(submission_id)
    if @submission.course_user_datum.course != @course
      render plain: "Unauthorized", status: :forbidden
      return
    end
    @assessment = @submission.assessment
    @student_email = @submission.course_user_datum.user.email

    render partial: "excuse_popover", locals: {
      email: @student_email,
      submission: @submission
    }
  rescue ActiveRecord::RecordNotFound
    render plain: "Submission not found", status: :not_found
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
        FilesystemEnforcer.fix_tree(assessment_path.to_s)
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
      FilesystemEnforcer.fix_tree(@assessment.folder_path.to_s)
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
    @problem = @assessment.problems.find_by(id: params[:problem])
    if @problem.nil?
      flash[:error] = "Could not find problem #{params[:problem]}"
      redirect_to(course_assessment_path(@course, @assessment)) && return
    end
    @submission = @assessment.submissions.find_by(id: params[:submission])
    if @submission.nil?
      flash[:error] = "Could not find submission #{params[:submission]}"
      redirect_to(course_assessment_path(@course, @assessment)) && return
    end
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
      FilesystemEnforcer.fix_path(assessment_config_file_path.to_s)

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

===== app/controllers/assessment/handin.rb =====
require "pathname"

##
# Handles different handin methods, including web form, local_submit and log_submit
#
module AssessmentHandin
  include AssessmentHandinCore

  # handin - The generic default handin function.
  # This function calls out to smaller helper functions which provide for
  # specific functionality.
  #
  # validateHandin_forHTML() : Returns true or false if the handin is valid.
  # saveHandin() : Does the actual process of saving the handin to the
  #     database and writing the handin file to Disk.
  # sendJob_AddHTMLMessages(course, assessment, submissions): Autogrades the submission.
  #
  # validateHandin_forHTML() cannot modify the state of the world in any way. And it should
  # call super() to enable any other functionality.  The only reason to not call super()
  # is if you want to prevent other functionality. You should be very careful about this.
  #
  # Any errors should be added to flash[:error] and return false or nil.
  def handin
    if @assessment.disable_handins?
      flash[:error] = "Sorry, handins are disabled for this assessment."
      redirect_to(action: :show)
      return false
    end

    # Clear cache since new submission made, need to remake cache
    Rails.cache.delete(["submission_ids", @assessment.id])
    Rails.cache.delete(["submissions_to_cud", @assessment.id])

    if @assessment.embedded_quiz
      contents = params[:submission]["embedded_quiz_form_answer"].to_s
      out_file = Tempfile.new('out.txt-')
      out_file.puts(contents)
      params[:submission]["file"] = out_file
    elsif @assessment.github_submission_enabled && params["github_submission"].present?
      # get code from Github
      github_integration = current_user.github_integration

      begin
        @tarfile_path = github_integration.clone_repo(params["repo"], params["branch"], params["commit"], @assessment.max_size * (2 ** 20))
      rescue StandardError => msg
        flash[:error] = msg
        redirect_to(action: :show)
        return
      end

      # Populate submission field for validation
      params[:submission] = { "tar" => @tarfile_path }
      git_tarfile_cleanup_path = @tarfile_path

      redirect_to(action: :show) && return unless validateHandin_forGit
    else
      # validate the handin
      redirect_to(action: :show) && return unless validateHandin_forHTML
    end

    # save the submissions
    begin
      submissions = saveHandin(params[:submission])
      if git_tarfile_cleanup_path
        system *%W(rm #{git_tarfile_cleanup_path})
      end
    rescue StandardError => exception
      ExceptionNotifier.notify_exception(exception, env: request.env,
                                                    data: {
                                                      user: current_user,
                                                      course: @course,
                                                      assessment: @assessment,
                                                    })

      COURSE_LOGGER.log("could not save handin: #{exception.class} (#{exception.message})")
      flash[:error] = exception.message
      submissions = nil
    end

    if @assessment.embedded_quiz
      out_file.close
      out_file.unlink
    end

    # make sure submission was correctly constructed and saved
    unless submissions
      flash[:error] ||= "There was an error handing in your submission."
      redirect_to(action: :show) && return
    end

    # autograde the submissions only if there are problems defined
    if @assessment.problems.length == 0
      flash[:error] = "There are no problems in this assessment."
    elsif @assessment.has_autograder?
      begin
        sendJob_AddHTMLMessages(@course, @assessment, submissions)
      rescue AssessmentAutogradeCore::AutogradeError => e
        # error message already filled in by sendJob_AddHTMLMessages, we just
        # log the error message
        COURSE_LOGGER.log("SendJob failed for #{submissions[0].id}\n
          User error message: #{flash[:error]}\n
          error name: #{e.error_code}\n
          additional error data: #{e.additional_data}")
      end
    end

    redirect_to([:history, @course, @assessment]) && return
  end

  # method called when student makes
  # unofficial submission in the database
  def local_submit
    @user = User.find_by(email: params[:user])
    @cud = @user ? @course.course_user_data.find_by(user_id: @user.id) : nil
    unless @cud
      err = "ERROR: invalid username (#{params[:user]}) for class #{@course.id}"
      render(plain: err, status: :bad_request) && return
    end

    @assessment = @course.assessments.find_by(name: params[:name])
    if !@assessment
      err = "ERROR: Invalid Assessment (#{params[:id]}) for course #{@course.id}"
      render(plain: err, status: :bad_request) && return
    elsif @assessment.remote_handin_path.nil? || @assessment.remote_handin_path.empty?
      err = "ERROR: Remote handins have not been enabled by the instructor."
      render(plain: err, status: :bad_request) && return
    end

    personal_directory = @user.email + "_remote_handin_" + @assessment.name
    remote_handin_dir = File.join(@assessment.remote_handin_path, personal_directory)
    remote_handin_path = Pathname.new(@assessment.remote_handin_path).expand_path
    remote_handin_dir_path = Pathname.new(remote_handin_dir).expand_path

    # https://stackoverflow.com/questions/39581798/check-if-file-folder-is-in-a-subdirectory-in-ruby
    # Validate that the handin directory lies strictly within remote handin path
    # Note: The fnmatch? check is ALMOST sufficient, except when the paths are /
    is_dir_underneath = ((remote_handin_dir_path.fnmatch? File.join(remote_handin_path.to_s, "**")) and
      (remote_handin_dir_path != remote_handin_path))

    unless is_dir_underneath
      # No way to reasonably handle this, so return an error
      render(plain: "Unable to create handin directory for user", status: :bad_request) && return
    end

    if params[:submit]
      # They've copied their handin over, lets go grab it.
      begin
        handin_file = params[:submit]

        if @assessment.max_submissions != -1
          submission_count = @cud.submissions.where(assessment: @assessment).size
          if submission_count >= @assessment.max_submissions
            render(plain: "You have no remaining submissions for this assessment",
                   status: :bad_request) && return
          end
        end

        render(plain: flash[:error], status: :bad_request) && return unless validateHandinForGroups_forHTML

        remote_handin_file = File.join(remote_handin_dir, handin_file)
        remote_handin_file_path = Pathname.new(remote_handin_file).expand_path

        # Validate that the handin file lies strictly within the handin directory
        is_file_underneath = ((remote_handin_file_path.fnmatch? File.join(remote_handin_dir_path.to_s, "**")) and
          (remote_handin_file_path != remote_handin_dir_path))

        unless is_file_underneath
          render(plain: "Invalid path to file", status: :bad_request) && return
        end

        # save the submissions
        begin
          submissions = saveHandin("local_submit_file" => remote_handin_file_path)
        rescue StandardError => e
          ExceptionNotifier.notify_exception(e, env: request.env,
                                                data: {
                                                  user: current_user,
                                                  course: @course,
                                                  assessment: @assessment,
                                                })
          COURSE_LOGGER.log("Error Saving Submission:\n#{e}")
          flash[:error] = exception.message
          submissions = nil
        end

        # make sure submission was correctly constructed and saved
        unless submissions
          flash[:error] ||= "There was an error handing in your submission."
          render(plain: flash[:error], status: :bad_request) && return
        end

        # autograde the submissions
        sendJob_AddHTMLMessages(@course, @assessment, submissions) if @assessment.has_autograder?
      rescue StandardError => e
        ExceptionNotifier.notify_exception(e, env: request.env,
                                              data: {
                                                user: current_user,
                                                course: @course,
                                                assessment: @assessment,
                                                submission: submissions[0],
                                              })
        COURSE_LOGGER.log(e.to_s)
      end

      if submissions
        COURSE_LOGGER.log("Submission received, ID##{submissions[0].id}")
      else
        err = "There was an error saving your submission. Please contact your course staff\n"
        render(plain: err, status: :bad_request) && return
      end

      if @assessment.max_submissions != -1
        remaining = @assessment.max_submissions - submissions.count
        render(plain: " - You have #{remaining} submissions left\n") && return
      end

      render(plain: "Successfully submitted\n") && return
    else

      # Create a handin directory for them.

      # The handin Directory really should not exist, as this script deletes it
      # when it's done.  However, if it's there, we'll try to remove an empty
      # folder, else fail w/ error message.
      if Dir.exist?(remote_handin_dir)
        begin
          FileUtils.rm_rf(remote_handin_dir)
        rescue SystemCallError => exception
          ExceptionNotifier.notify_exception(exception, env: request.env,
                                                        data: {
                                                          user: current_user,
                                                          course: @course,
                                                          assessment: @assessment,
                                                        })
          render(plain: "WARNING: could not clear previous handin directory, please") && return
        end
      end

      begin
        Dir.mkdir(remote_handin_dir)
      rescue SystemCallError
        ExceptionNotifier.notify_exception(exception, env: request.env,
                                                      data: {
                                                        user: current_user,
                                                        course: @course,
                                                        assessment: @assessment,
                                                      })
        COURSE_LOGGER.log("ERROR: Could not create handin directory. Please contact
        #{Rails.configuration.school["support_email"]} with this error")
      end

      system("fs sa #{remote_handin_dir} #{@user.email} rlidw")
    end

    render(plain: remote_handin_dir) && return
  end

  # method called when student makes
  # log submission in the database
  def log_submit
    @user = User.find_by(email: params[:user])
    @cud = @user ? @course.course_user_data.find_by(user_id: @user.id) : nil
    unless @cud
      err = "ERROR: invalid username (#{params[:user]}) for class #{@course.id}"
      render(plain: err, status: :bad_request) && return
    end

    @assessment = @course.assessments.find_by(name: params[:name])
    if !@assessment
      err = "ERROR: Invalid Assessment (#{params[:id]}) for course #{@course.id}"
      render(plain: err, status: :bad_request) && return
    elsif !@assessment.allow_unofficial
      err = "ERROR: This assessment does not allow Log Submissions"
      render(plain: err, status: :bad_request) && return
    end

    @result = params[:result]
    render(plain: "ERROR: No result!", status: :bad_request) && return unless @result

    # Everything looks OK, so append the autoresult to the log.txt file for this lab
    ASSESSMENT_LOGGER.setAssessment(@assessment)
    ASSESSMENT_LOGGER.log("#{@user.email},0,#{@result}")

    render(plain: "OK", status: 200) && return
  end

  private

  ##
  # this function checks that now is a valid time to submit and that the
  # submission file is okay to submit.
  #
  def validateHandin_forHTML
    if params[:submission].blank?
      flash[:error] = "Submission was blank - please upload again."
      return false
    end

    if params[:submission]["file"].blank? and params["repo"].blank?
      flash[:error] = "Submission was blank (file upload/Github repository missing) - please try again."
      return false
    end

    validity = validateHandin(params[:submission]["file"].size,
                              params[:submission]["file"].content_type,
                              params[:submission]["file"].original_filename)

    return handle_validity(validity)
  end

  ##
  # Validates Git tarfile
  #
  def validateHandin_forGit
    if @tarfile_path.blank?
      flash[:error] = "Git submission error"
      return false
    end

    validity = validateHandin(File.size(@tarfile_path),
                              MimeMagic.by_magic(File.open(@tarfile_path)).type,
                              @tarfile_path) # TODO probably want filename instead of path

    return handle_validity(validity)
  end

  ##
  # this function makes sure that the submitter's group can submit.
  # If the assessment does not have groups, or the user has no group,
  # this returns true.  Otherwise, it checks that everyone is confirmed
  # to be in the group and that no one is over the submission limit.
  #
  def validateHandinForGroups_forHTML
    validity = validateHandinForGroups

    case validity
    when :valid
      return true
    when :awaiting_member_confirmation
      msg = "You cannot submit until all group members confirm their group membership"
    when :group_submission_limit_exceeded
      msg = "A member of your group has reached the submission limit for this assessment"
    end

    flash[:error] = msg
    return false
  end

  def handle_validity(validity)
    case validity
    when :valid
      return validateHandinForGroups_forHTML
    when :handin_disabled
      msg = "Sorry, handins are disabled for this assessment."
    when :submission_empty
      msg = "Submission was blank - please upload again."
    when :file_too_large
      msg = "Your submission is larger than the max allowed " \
            "size (#{@assessment.max_size} MB) - please remove any " \
            "unnecessary logfiles and binaries."
    when :fail_type_check
      flash[:error] = "" if flash[:error].nil?
      msg = "Submission failed Filetype Check. " + flash[:error]
    end

    flash[:error] = msg
    return false
  end

  def set_handin
    submission_count = @assessment.submissions.where(course_user_datum_id: @cud.id).count
    @left_count = [@assessment.max_submissions - submission_count, 0].max
    @aud = AssessmentUserDatum.get @assessment.id, @cud.id
    @can_submit, @why_not = @aud.can_submit? Time.now

    @submission = Submission.new
  end
end

===== app/controllers/file_manager_controller.rb =====
# Code for file manager adapted from: adrientoub/file-explorer
require 'archive'
require 'pathname'
require 'mimemagic'

class FileManagerController < ApplicationController
  BASE_DIRECTORY = Rails.root.join('courses')
  skip_before_action :set_course
  skip_before_action :authorize_user_for_course
  skip_before_action :update_persistent_announcements

  def index
    path = params[:path].nil? ? "" : params[:path]
    new_url = "#{path}/"
    parts = new_url.split('/')
    if parts.empty?
      @title = "File Manager"
    else
      @breadcrumbs << view_context.link_to("File Manager", file_manager_index_path)
    end
    parts.each_with_index do |part, index|
      path = new_url.split('/').slice(0, index + 1).join("/")
      if index == parts.length - 1
        @title = part
      else
        @breadcrumbs << view_context.link_to(part, "/file_manager/#{path}")
      end
    end
    absolute_path = check_path_exist(path)
    if (File.directory?(absolute_path) && check_instructor(absolute_path)) ||
       (path == "" && is_instructor_of_any_course)
      populate_directory(absolute_path, new_url)
      render 'file_manager/index'
    elsif File.file?(absolute_path) && check_instructor(absolute_path)
      if File.size(absolute_path) > 1_000_000 || params[:download]
        send_file absolute_path
      elsif !is_binary_file?(absolute_path)
        @path = path
        @file = absolute_path.read
        render :file, formats: :html
      else
        send_file(absolute_path,
                  filename: File.basename(absolute_path),
                  disposition: 'attachment')
      end
    else
      flash[:error] = "You are not authorized to view this path"
      redirect_to root_path
    end
  end

  def upload
    upload_file(params[:path].nil? ? "" : params[:path])
  end

  def delete
    absolute_path = check_path_exist(params[:path])
    if check_instructor(absolute_path)
      parent = absolute_path.parent
      raise "Unable to delete courses in the root directory." if parent == BASE_DIRECTORY

      FileUtils.rm_rf(absolute_path)
    else
      flash[:error] = "You are not authorized to delete this"
      redirect_to root_path
    end
  end

  def rename
    absolute_path = check_path_exist(params[:relative_path])
    if check_instructor(absolute_path)
      parent = absolute_path.parent
      if parent == BASE_DIRECTORY
        flash[:error] = "Unable to rename courses in the root directory."
      else
        dir_name = File.dirname(params[:relative_path].to_s)

        if params[:new_name].nil? || params[:new_name].empty?
          raise ArgumentError, "New name not provided"
        end

        unless params[:new_name].match(/\A[a-zA-Z0-9_\-.\s]+\Z/)
          raise ArgumentError, "Invalid characters. Only letters,
        numbers, underscores, and hyphens are allowed."
        end

        new_path = safe_expand_path("#{dir_name}/#{params[:new_name]}")
        parent = new_path.split[0..-2].join('/')

        raise ArgumentError, "A file with that name already exists" if File.exist?(new_path)

        FileUtils.mkdir_p(parent)
        FileUtils.mv(absolute_path, new_path)
        FilesystemEnforcer.fix_path(new_path.to_s)
        flash[:success] = "Successfully renamed file to #{params[:new_name]}"
      end
    else
      flash[:error] = "You are not authorized to rename this path"
      redirect_to root_path
    end
  rescue ArgumentError => e
    flash[:error] = e.message
  end

  def download_tar
    path = params[:path]&.split("/")&.drop(2)&.join("/")
    path = CGI.unescape(path)
    absolute_path = check_path_exist(path)
    if check_instructor(absolute_path)
      if File.directory?(absolute_path)
        tar_stream = StringIO.new("")
        Gem::Package::TarWriter.new(tar_stream) do |tar|
          Dir[File.join(absolute_path.to_s, '**', '**')].each do |file|
            mode = File.stat(file).mode
            relative_path = file.sub(%r{^#{Regexp.escape(absolute_path.to_s)}/?}, '')
            if File.directory?(file)
              tar.mkdir relative_path, mode
            else
              tar.add_file relative_path, mode do |tar_file|
                File.open(file, "rb") { |f| tar_file.write f.read }
              end
            end
          end
        end
        tar_stream.rewind
        tar_stream.close
        send_data tar_stream.string.force_encoding("binary"),
                  filename: "file_manager.tar",
                  type: "application/x-tar",
                  disposition: "attachment"
      else
        send_file(absolute_path,
                  filename: File.basename(absolute_path),
                  disposition: 'attachment')
      end
    else
      flash[:error] = "You are not authorized to download attachments at this path"
      redirect_to root_path
    end
  end

  def upload_file(path)
    absolute_path = check_path_exist(path)
    if Archive.in_dir?(BASE_DIRECTORY, absolute_path, strict: false)
      raise "You cannot upload files/create folders in the root directory click " \
        "#{view_context.link_to 'here', new_course_url, method: 'get'}" \
        " if you want to create a new course."
    else
      raise ActionController::ForbiddenError unless File.directory?(absolute_path)

      if check_instructor(absolute_path) && !params[:name].nil?
        all_filenames = Dir.entries(absolute_path)
        if params[:name] != ""
          if all_filenames.include?(params[:name].to_s)
            raise "File with name #{input_file.original_filename} already exists."
          end

          # Creating a folder
          dir = "#{absolute_path}/#{params[:name]}"
          FileUtils.mkdir_p(dir)
          FilesystemEnforcer.fix_path(dir)

        else
          # Uploading a file
          input_file = params[:file]
          return unless input_file
          if all_filenames.include?(input_file.original_filename)
            raise "File with name #{input_file.original_filename} already exists."
          elsif input_file.size >= 1.gigabyte
            raise "File size is too large. Upload a file that is smaller than 1 GB."
          else
            dest = absolute_path.join(input_file.original_filename) 
            File.open(dest, 'wb') { |f| f.write(input_file.read) }
            FilesystemEnforcer.fix_path(dest.to_s)          
          end
        end
      else
        flash[:error] = "You are not authorized to upload files at this path"
        redirect_to root_path
      end
    end
  end

private

  def populate_directory(current_directory, current_url)
    directory = Dir.entries(current_directory)
    new_url = current_url == '/' ? '' : current_url
    @directory = directory.map do |file|
      abs_path_str = "#{current_directory}/#{file}"
      stat = File.stat(abs_path_str)
      is_file = stat.file?
      if %w[. ..].include?(file)
        inst = true
        if current_directory == BASE_DIRECTORY
          inst = false
        end
      else
        abs_path = Pathname.new(abs_path_str)
        inst = check_instructor(abs_path)
      end
      {
        size: (if is_file
                 begin
                   stat.size
                 rescue StandardError
                   '-'
                 end
               else
                 '-'
               end),
        type: (is_file ? :file : :directory),
        date: begin
          stat.mtime.strftime('%d %b %Y %H:%M')
        rescue StandardError
          '-'
        end,
        relative: "/file_manager/#{new_url}#{file}",
        entry: "#{file}#{is_file ? '' : '/'}",
        absolute: abs_path_str,
        instructor: inst,
      }
    end.sort_by { |entry| "#{entry[:type]}#{entry[:relative]}" }
  end

  def safe_expand_path(path)
    current_directory = Pathname.new(BASE_DIRECTORY)
    tested_path = Pathname.new(File.join(BASE_DIRECTORY, path))
    unless Archive.in_dir?(tested_path, current_directory, strict: false)
      raise ArgumentError, 'Should not be parent of root'
    end

    tested_path
  end

  def check_path_exist(path)
    @absolute_path = safe_expand_path(path)
    @relative_path = path
    raise ActionController::RoutingError, 'Not Found' unless File.exist?(@absolute_path)

    @absolute_path
  end

  def is_instructor_of_any_course
    current_user_id = current_user.id
    cuds = CourseUserDatum.where(user_id: current_user_id, instructor: true)
    courses = Course.where(id: cuds.map(&:course_id))
    !courses.empty?
  end

  def check_instructor(path)
    current_user_id = current_user.id
    cuds = CourseUserDatum.where(user_id: current_user_id, instructor: true)
    courses = Course.where(id: cuds.map(&:course_id))
    courses.map do |course|
      course_path = Pathname.new("#{BASE_DIRECTORY}/#{course.name}")
      if Archive.in_dir?(path, course_path, strict: false)
        return true
      end
    end
    false
  end

  def is_binary_file?(path)
    mm = MimeMagic.by_path(path)
    mm.present? && !mm.text?
  end
end

===== app/models/course.rb =====
require "association_cache"
require "fileutils"

class Course < ApplicationRecord
  trim_field :name, :semester, :display_name
  validates :name, uniqueness: { case_sensitive: false }
  validates :display_name, :start_date, :end_date, presence: true
  validates :late_slack, :grace_days, :late_penalty, :version_penalty, presence: true
  validates :grace_days, numericality: { greater_than_or_equal_to: 0 }
  validates :version_threshold, numericality: { only_integer: true, greater_than_or_equal_to: -1 }
  validate :order_of_dates
  validate :valid_name?, on: :create
  validate :valid_website?
  validates :access_code, uniqueness: true, allow_nil: true

  has_many :course_user_data, dependent: :destroy
  has_many :assessments, dependent: :destroy
  has_many :scheduler, dependent: :destroy

  has_many :announcements, dependent: :destroy
  has_many :attachments, dependent: :destroy
  belongs_to :late_penalty, class_name: "Penalty"
  belongs_to :version_penalty, class_name: "Penalty"
  has_many :assessment_user_data, through: :assessments
  has_many :submissions, through: :assessments
  has_many :watchlist_instances, dependent: :destroy
  has_many :risk_conditions, dependent: :destroy
  has_one :watchlist_configuration, dependent: :destroy
  has_one :lti_course_datum, dependent: :destroy

  # Callbacks
  before_save :cgdub_dependencies_updated, if: :grace_days_or_late_slack_changed?
  before_create :cgdub_dependencies_updated
  after_create :init_course_folder

  # Constants
  VALID_CODE_REGEX = /\A[A-Z0-9]{6}\z/
  VALID_CODE_REGEX_HTML = "[a-zA-Z0-9]{6}".freeze

  # Misc.
  accepts_nested_attributes_for :late_penalty, :version_penalty

  def config_file_path
    Rails.root.join("courseConfig", "#{sanitized_name}.rb")
  end

  def config_backup_file_path
    config_file_path.sub_ext(".rb.bak")
  end

  def directory_path
    Rails.root.join("courses", name)
  end

  # Create a course with name, semester, and instructor email
  # all other fields are filled in automatically
  def self.quick_create(unique_name, semester, instructor_email)
    newCourse = Course.new(name: unique_name, semester:)
    newCourse.display_name = newCourse.name

    # fill temporary values in other fields
    newCourse.late_slack = 0
    newCourse.grace_days = 0
    newCourse.start_date = Time.current
    newCourse.end_date = Time.current

    newCourse.late_penalty = Penalty.new(kind: "points", value: "0")
    newCourse.version_penalty = Penalty.new(kind: "points", value: "0")

    unless newCourse.save
      raise "Failed to create course #{newCourse.name}: " \
            "#{newCourse.errors.full_messages.join(', ')}"
    end

    instructor = User.where(email: instructor_email).first
    if instructor.nil?
      begin
        instructor = User.instructor_create(instructor_email, newCourse.name)
      rescue StandardError => e
        newCourse.destroy
        raise "Failed to create instructor for course: #{e}"
      end
    end

    newCUD = newCourse.course_user_data.new
    newCUD.user = instructor
    newCUD.instructor = true
    unless newCUD.save
      newCourse.destroy
      raise "Failed to create CUD for instructor of new course #{newCourse.name}"
    end

    begin
      newCourse.reload_course_config
    rescue StandardError, SyntaxError
      newCUD.destroy
      newCourse.destroy
    end

    newCourse
  end

  # generate course folder
  def init_course_folder
    dir_path = directory_path

    # Ensure base dirs exist first, then normalize
    FileUtils.mkdir_p dir_path
    FileUtils.mkdir_p Rails.root.join("assessmentConfig")
    FileUtils.mkdir_p Rails.root.join("courseConfig")
    FilesystemEnforcer.fix_path(dir_path.to_s)
    FilesystemEnforcer.fix_path(Rails.root.join("assessmentConfig").to_s)
    FilesystemEnforcer.fix_path(Rails.root.join("courseConfig").to_s)

    # Touch log and copy default course.rb
    FileUtils.touch File.join(dir_path, "autolab.log")
    course_rb = File.join(dir_path, "course.rb")
    default_course_rb = Rails.root.join("lib", "__defaultCourse.rb") # rubocop:disable Rails/FilePath
    FileUtils.cp default_course_rb, course_rb

    # Sweep perms/ownership on created trees
    FilesystemEnforcer.fix_tree(dir_path.to_s)
    FilesystemEnforcer.fix_tree(Rails.root.join("assessmentConfig").to_s)
    FilesystemEnforcer.fix_tree(Rails.root.join("courseConfig").to_s)
  end

  def order_of_dates
    return if start_date.nil? || end_date.nil?

    errors.add(:start_date, "must come before end date") if start_date > end_date
  end

  def valid_name?
    if /\A(\w|-)+\z/.match?(name)
      true
    else
      suggest_name = name.gsub(/(\s+)/, "-").gsub(/([^\w-]+)/, "")
      name_error =
        if !suggest_name.empty?
          "cannot include characters other than alphanumeric characters, hyphens, " \
          "and underscores. Suggestion: #{suggest_name}"
        else
          "cannot include characters other than alphanumeric characters, hyphens, and underscores."
        end
      errors.add("name", name_error)
      false
    end
  end

  def valid_website?
    return true if website.nil? || website.eql?("")
    return true if website[0..7].eql?("https://")

    errors.add("website", "needs to start with https://")
    false
  end

  def temporal_status(now = DateTime.now)
    if now < start_date
      :upcoming
    elsif now > end_date
      if disable_on_end
        :disabled
      else
        :completed
      end
    else
      :current
    end
  end

  def is_disabled?
    disabled? || (disable_on_end? && DateTime.now > end_date)
  end

  def current_assessments(now = DateTime.now)
    assessments.where("start_at < :now AND end_at > :now", now:)
  end

  def full_name
    if !semester.to_s.empty?
      "#{display_name} (#{semester})"
    else
      display_name
    end
  end

  def source_config_file_path
    Rails.root.join("courses", name, "course.rb")
  end

  def reload_config_file
    s = File.open(source_config_file_path, "r")
    lines = s.readlines
    s.close

    config_source = File.open(source_config_file_path, "r", &:read)
    RubyVM::InstructionSequence.compile(config_source)

    if File.exist? config_file_path
      File.rename(config_file_path, config_backup_file_path)
      FilesystemEnforcer.fix_path(config_backup_file_path.to_s)
    end

    d = File.open(config_file_path, "w")
    d.write("require 'CourseBase.rb'\n\n")
    d.write("module #{config_module_name}\n")
    d.write("\tinclude CourseBase\n\n")
    lines.each do |line|
      if !line.empty?
        d.write("\t#{line}")
      else
        d.write(line)
      end
    end
    d.write("end")
    d.close
    FilesystemEnforcer.fix_path(config_file_path.to_s)

    load(config_file_path)
    # rubocop:disable Security/Eval
    eval(config_module_name)
    # rubocop:enable Security/Eval
  end

  # Reload the course config file and extend the loaded methods to AdminsController
  def reload_course_config
    mod = reload_config_file
    AdminsController.extend(mod)
  end

  def sanitized_name
    name.gsub(/[^A-Za-z0-9]/, "")
  end

  def invalidate_cgdubs
    cgdub_dependencies_updated
    save!
  end

  # NOTE: Needs to be updated as new items are cached
  def invalidate_caches
    invalidate_cgdubs
    # rubocop:disable Rails/SkipsModelValidations
    assessments.update_all(updated_at: Time.current)
    # rubocop:enable Rails/SkipsModelValidations
  end

  def config
    @config ||= config!
  end

  def students
    course_user_data.where(course_assistant: false, instructor: false, dropped: [false, nil])
  end

  def instructors
    course_user_data.where(instructor: true)
  end

  def assessment_categories
    assessments.unscope(:order).distinct.pluck(:category_name).sort
  end

  def assessments_with_category(cat_name, is_student = false)
    if is_student
      assessments.where(category_name: cat_name).ordered.released
    else
      assessments.where(category_name: cat_name).ordered
    end
  end

  def to_param
    name
  end

  def asmts_before_date(date)
    asmts = assessments.ordered
    asmts.where("due_at < ?", date)
  end

  def exclude_curr_asmts(asmts)
    date = DateTime.current
    asmts.reject { |asmt| asmt.due_at > date }
  end

  def get_autocomplete_data
    users = {}
    usersEncoded = {}
    course_user_data.each do |cud|
      users[CGI.escapeHTML cud.full_name_with_email] = cud.id
      usersEncoded[Base64.strict_encode64(cud.full_name_with_email.strip).strip] = cud.id
    end
    [users, usersEncoded]
  end

  def watchlist_allow_ca
    return false if watchlist_configuration.nil?

    watchlist_configuration.allow_ca
  end

  def dump_yaml(include_metrics)
    YAML.dump(serialize(include_metrics))
  end

  def generate_tar(export_configs)
    base_path = Rails.root.join("courses", name).to_s
    course_dir = name
    rb_path = "course.rb"
    config_path = "#{name}.yml"
    mode = 0o755

    begin
      tarStream = StringIO.new("")
      Gem::Package::TarWriter.new(tarStream) do |tar|
        tar.mkdir course_dir, File.stat(File.join(base_path)).mode

        # save course.rb
        source_file = File.open(File.join(base_path, rb_path), "rb")
        tar.add_file File.join(course_dir, rb_path), File.stat(source_file).mode do |tar_file|
          tar_file.write(source_file.read)
        end
        source_file.close

        # save course and metrics config
        tar.add_file File.join(course_dir, config_path), mode do |tar_file|
          tar_file.write(dump_yaml(export_configs&.include?("metrics_config")))
        end

        # save assessments
        if export_configs&.include?("assessments")
          assessments.each do |assessment|
            asmt_dir = assessment.name
            assessment.dump_yaml
            filter = [assessment.handin_directory_path]
            assessment.load_dir_to_tar(base_path, asmt_dir, tar, filter, course_dir)
          end
        end
      end
      tarStream.rewind
      tarStream.close
      tarStream
    end
  end

  private

  def saved_change_to_grade_related_fields?
    saved_change_to_late_slack? || saved_change_to_grace_days? ||
      saved_change_to_version_threshold? || saved_change_to_late_penalty_id? ||
      saved_change_to_version_penalty_id?
  end

  def grace_days_or_late_slack_changed?
    grace_days_changed? || late_slack_changed?
  end

  def saved_change_to_grace_days_or_late_slack?
    saved_change_to_grace_days? || saved_change_to_late_slack?
  end

  def cgdub_dependencies_updated
    self.cgdub_dependencies_updated_at = Time.current
  end

  def config!
    source = "#{name}_course_config".to_sym
    Utilities.execute_instructor_code(source) do
      require config_file_path
      # rubocop:disable Security/Eval
      Class.new.extend eval(config_module_name)
      # rubocop:enable Security/Eval
    end
  end

  def config_module_name
    "Course#{sanitized_name.camelize}"
  end

  def serialize(include_metrics)
    s = {}
    s["general"] = serialize_general
    s["general"]["late_penalty"] = late_penalty.serialize unless late_penalty.nil?
    s["general"]["version_penalty"] = version_penalty.serialize unless version_penalty.nil?
    s["attachments"] = attachments.map(&:serialize) if attachments.exists?

    if include_metrics
      if risk_conditions.exists?
        s["risk_conditions"] = risk_conditions.map(&:serialize)
        latest_version = risk_conditions.order(version: :desc).first.version
        s["risk_conditions"] = risk_conditions.where(version: latest_version).map(&:serialize)
      end

      if watchlist_configuration.present?
        s["watchlist_configuration"] = watchlist_configuration.serialize
      end
    end
    s
  end

  GENERAL_SERIALIZABLE = Set.new %w[name semester late_slack grace_days display_name start_date
                                    end_date disabled exam_in_progress version_threshold
                                    gb_message website disable_on_end]
  def serialize_general
    Utilities.serializable attributes, GENERAL_SERIALIZABLE
  end

  include CourseAssociationCache
end

