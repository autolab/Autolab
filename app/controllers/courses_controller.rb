require "archive"
require "csv"
require "fileutils"
require "pathname"
require "statistics"

class CoursesController < ApplicationController
  skip_before_action :set_course, only: %i[courses_redirect index new create]
  # you need to be able to pick a course to be authorized for it
  skip_before_action :authorize_user_for_course, only: %i[courses_redirect index new create]
  # if there's no course, there are no persistent announcements for that course
  skip_before_action :update_persistent_announcements, only: %i[courses_redirect index new create]

  rescue_from ActionView::MissingTemplate do |_exception|
    redirect_to("/home/error_404")
  end

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
          flash[:error] = "Can't create instructor for the course: #{e}"
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
          flash[:error] = "Can't load course config for #{@newCourse.name}."
          render(action: "new") && return
        else
          flash[:success] = "New Course #{@newCourse.name} successfully created!"
          redirect_to(edit_course_path(@newCourse)) && return
        end
      else
        # roll back course creation
        @newCourse.destroy
        flash[:error] = "Can't create instructor for the course."
        render(action: "new") && return
      end

    else
      flash[:error] = "Course creation failed. Check all fields"
      render(action: "new") && return
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
        { email: email }
      end
    end

    # filter out nil emails
    user_emails = user_emails.reject(&:nil?)

    # check if email matches regex
    email_regex = /\A[\w+\-.]+@[a-z\d\-]+(\.[a-z\d\-]+)*\.[a-z]+\z/i

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
    output = ""
    @cuds.each do |cud|
      user = cud.user
      # to_csv avoids issues with commas
      output += [@course.semester, cud.user.email, user.last_name, user.first_name,
                 cud.school, cud.major, cud.year, cud.grade_policy,
                 @course.name, cud.lecture, cud.section].to_csv
    end
    send_data output, filename: "roster.csv", type: "text/csv", disposition: "inline"
  end

  # install_assessment - Installs a new assessment, either by
  # creating it from scratch, or importing it from an existing
  # assessment directory.
  action_auth_level :install_assessment, :instructor
  def install_assessment
    @assignDir = Rails.root.join("courses", @course.name)
    @availableAssessments = []
    begin
      Dir.foreach(@assignDir) do |filename|
        if File.exist?(File.join(@assignDir, filename, "#{filename}.rb"))
          # names must be only lowercase letters and digits
          next if filename =~ /[^a-z0-9]/

          # Only list assessments that aren't installed yet
          assessment = @course.assessments.where(name: filename).first
          @availableAssessments << filename unless assessment
        end
      end
      @availableAssessments = @availableAssessments.sort
    rescue StandardError => e
      render(text: "<h3>#{e}</h3>", layout: true) && return
    end
  end

  # email - The email action allows instructors to email the entire course, or
  # a single section at a time.  Sections are passed via params[:section].
  action_auth_level :email, :instructor
  def email
    return unless request.post?

    section = (params[:section] if !params[:section].empty?)

    # don't email kids who dropped!
    @cuds = if section
              @course.course_user_data.where(dropped: false, section: section)
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
  def moss; end

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
      assessment = Assessment.find(aid)
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
    `~/Autolab/script/cleanMoss #{tmp_dir}`
    # Now run the Moss command
    @mossCmdString = @mossCmd.join(" ")
    @mossOutput = `#{@mossCmdString} 2>&1`
    @mossExit = $?.exitstatus

    # Clean up after ourselves (droh: leave for debugging)
    `rm -rf #{tmp_dir}`
  end

private

  def new_course_params
    params.require(:newCourse).permit(:name, :semester)
  end

  def edit_course_params
    params.require(:editCourse).permit(:semester, :website, :late_slack,
                                       :grace_days, :display_name, :start_date, :end_date,
                                       :disabled, :exam_in_progress, :version_threshold,
                                       :gb_message, late_penalty_attributes: %i[kind value],
                                                    version_penalty_attributes: %i[kind value])
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

        if (user = User.where(email: email).first).nil?
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

        existing = @course.course_user_data.where(user: user).first
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
        if !user.nil?
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

    rowCUDs.each do |cud|
      next unless duplicates.include?(cud[:email])

      msg = "Validation failed: Duplicate email #{cud[:email]}"
      if !rosterErrors.key?(msg)
        rosterErrors[msg] = []
      end
      rosterErrors[msg].push(cud)
    end

    return if rosterErrors.empty?

    flash[:roster_error] = rosterErrors
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
      rescue StandardError => e
        redirect_to(action: "upload_roster")
      ensure
        raise ActiveRecord::Rollback
      end
    end

    @sorted_cuds = @cuds.sort_by { |cud| cud[:color] || "z" }
    @cud_view = @sorted_cuds
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
end
