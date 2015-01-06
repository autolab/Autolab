require "fileutils"

namespace :autolab do
  COURSE_NAME = "AutoPopulated"
  USER_COUNT = 50
  ASSESSMENT_CATEGORY_COUNT = 3
  ASSESSMENT_COUNT = 6
  PROBLEM_COUNT = 3 
  SUBMISSION_MAX = 3
  PROBLEM_MAX_SCORE = 100.0
  COURSE_START = Time.now - 80.days
  COURSE_END = COURSE_START + 1.years

  AUTOGRADE_CATEGORY_NAME = "CategoryAutograde"
  AUTOGRADE_TEMPLATE_DIR_PATH =
          File.join(Rails.root, "templates", "labtemplate")
  AUTOGRADE_TEMPLATE_CONFIG_PATH =
          File.join(Rails.root, "templates", "AutoPopulated-labtemplate.rb")
  AUTOGRADE_TEMPLATE_NAME = "labtemplate"
  AUTOGRADE_TEMPLATE_DISPLAY_NAME = "Lab Template"
  AUTOGRADE_TEMPLATE_MAX_SCORE = 100.0
  AUTOGRADE_TEMPLATE_PROBLEM_NAME = "autograded"
  AUTOGRADE_TEMPLATE_HANDIN_DIRECTORY = "handin"
  AUTOGRADE_TEMPLATE_HANDIN_FILENAME = "handin.py"

  def load_course name
    Course.create do |c|
      c.name = name
      c.semester = "SEM"
      c.late_slack = 0
      c.grace_days = 3 
      c.late_penalty = Penalty.new(:value => 5, :kind => "points")
      c.version_penalty = Penalty.new(:value => 5, :kind => "points")
      c.display_name = name
      c.start_date = COURSE_START
      c.end_date = COURSE_END

    end
  end

  def load_assessment_categories course
    ASSESSMENT_CATEGORY_COUNT.times do |i|
      course.assessment_categories.create do |c|
        c.name = "Category#{i.to_s}"
      end
    end
  end

  def load_assessments course
    course_dir = File.join(Rails.root, "courses", course.name)
    course.assessment_categories.each do |c|

      # start date for this category
      start = COURSE_START + rand(20).day

      ASSESSMENT_COUNT.times do |i|
        c.assessments.create do |a|
          a.visible_at = start 
          a.start_at = start
          a.due_at = start + (5 + rand(11)).days          # 5-15d after start date
          a.end_at = a.due_at + (1 + rand(7)).day   # 1d-1w after the due date
          a.grading_deadline = a.end_at + (1 + rand(7)).day   # 1-7d after submit deadline 

          a.name = "#{c.name}assessment#{i.to_s}".downcase
          a.display_name = "#{c.name}Assessment#{i.to_s}"
          a.handin_directory = "handin"
          a.handin_filename = "handin.c"
          a.course_id = course.id

          assessment_dir = File.join(course_dir, a.name)
          assessment_handin_dir = File.join(assessment_dir, a.handin_directory)
          FileUtils.mkdir_p(assessment_handin_dir)

          # 1-5 day buffer between assessments (in this category)
          start = a.due_at + (1 + rand(5)).day
        end
      end
    end
  end

  def load_problems course
    course.assessments.each do |a|
      PROBLEM_COUNT.times do |i|
        a.problems.create do |p|
          p.name = "problem#{i.to_s}"
          p.max_score = PROBLEM_MAX_SCORE
        end
      end
    end
  end

  def load_users course
    
    if User.where(:email => "admin@foo.bar").first then
      @grader = User.where(:email => "admin@foo.bar").first
    else
      @grader = User.new({
        first_name: "Autolab",
        last_name: "Administrator",

        password: 'adminfoobar',

        school: "SCS",
        major: "CS",
        year: "4",
        email: "admin@foo.bar",

        administrator: true
      })
      @grader.skip_confirmation!
      @grader.save
    end

    @grader_cud = CourseUserDatum.create!({
      :user => @grader,
      :course => course,

      :lecture => "1",
      :section => "Instructor",

      :instructor => true,
      :course_assistant => false,

      :nickname => "admin_#{course.name}"
    })

    i = 0
    User.populate(USER_COUNT, :per_query => 10000) do |u| 
      u.attributes = @default_user

      u.first_name = "User"
      u.last_name = i.to_s
      u.email = "user#{i.to_s}_#{course.name}@foo.bar"

      u.school = "SCS"
      u.major = "CS"
      u.year = (1 + rand(4)).to_s

      CourseUserDatum.populate(1) do |cud|
        cud.course_id = course.id
        cud.user_id = u.id

        cud.lecture = "1"
        cud.section = "None"

        cud.instructor = false
        cud.course_assistant = false

        cud.nickname = "user#{i.to_s}_#{course.name}"
      end

      i += 1
    end

    User.all.each do |u|
      u.skip_confirmation!
      u.save!
    end
  end

  def load_submissions course
    course.course_user_data.find_each do |cud|
      load_submissions_for course, cud
    end
  end

  def load_auds course
    # delete grader's AUDs (create_AUDs_module_callbacks insists on creating them)
    AssessmentUserDatum.delete_all(:course_user_datum_id => @grader_cud.id)

    course.assessments.each do |asmt|
      # create all auds
      Rails.logger.info "Creating AUDs for #{asmt.course.name}/#{asmt.name}..."
      asmt.create_AUDs_modulo_callbacks

      # update latest submissions
      Rails.logger.info "Updating AUDs with latest submissions..."
      asmt.update_latest_submissions_modulo_callbacks
    end
  end

  def load_submissions_for(course, cud)
    course_dir = File.join(Rails.root, "courses", course.name)
    user = cud.user

    course.assessments.each do |a|

      sub_count = 1 + rand(SUBMISSION_MAX)
      assessment_dir = File.join(course_dir, a.name)
      assessment_handin_dir = File.join(assessment_dir, a.handin_directory)

      # preprocess valid submission window for assessment
      submission_window = a.end_at - a.start_at

      i = 0
      Submission.populate(sub_count, :per_query => 10000) do |s|
        s.attributes = @default_submission

        s.created_at = s.updated_at = a.end_at - rand(submission_window)
        s.version = i + 1
        s.course_user_datum_id = cud.id
        s.submitted_by_id = cud.id
        s.filename = "#{user.email}_#{i.to_s}_#{a.handin_filename}"
        s.assessment_id = a.id
        s.tweak_id = nil

        # create a fake submission file
        submission_path = File.join(assessment_handin_dir, s.filename)
        FileUtils.mkdir_p(assessment_handin_dir)
        File.open(submission_path,'w+') do |f|
          f.write("int main() {\n  printf(\"Hello Dave!\\n\");\n  return 0;\n}")
        end

        load_scores_for s

        i += 1
      end
    end
  end

  def load_scores_for submission
    assessment = Assessment.find(submission.assessment_id)

    assessment.problems.each do |p|
      Score.populate(1, :per_query => 10000) do |score|
        score.attributes = @default_score

        score.score = rand(PROBLEM_MAX_SCORE.to_i).to_f
        score.problem_id = p.id
        score.grader_id = @grader_cud.id
        score.released = true
        score.submission_id = submission.id
      end
    end
  end

  def add_assessment_files course
    course_dir = File.join Rails.root, "courses", course.name

    course.assessments.each do |a|
      assessment_dir = File.join(course_dir, a.name)
      assessment_handin_dir = File.join(assessment_dir, a.handin_directory)
      assessment_template_path = File.join(Rails.root, "lib", "__defaultAssessment.rb")
      assessment_template = nil

      File.open(assessment_template_path) do |f|
        assessment_template = f.read
      end

      problem_hashes = ""
      PROBLEM_COUNT.times do |i|
        problem_hashes << "{ 'name' => 'problem#{i}', 'max_score' => '#{PROBLEM_MAX_SCORE + 0.0}', 'description' => ''},"
      end
      problem_string = "@problems = [#{problem_hashes}]"

      config_file_string = assessment_template.gsub("##NAME_CAMEL##", a.name.downcase.capitalize)
                                              .gsub("##NAME_LOWER##", a.name)
                                              .gsub("##PROBLEMS##", problem_string)

      config_file_path = File.join(assessment_dir, "#{a.name}.rb")
      File.open(config_file_path, "w") do |f|
        f.write config_file_string
      end

      # TODO (tabraham): figure this out
      # Assessment.reload_config_file(course, a.name)
    end
  end

  def load_autograde_assessment course

    course_dir = File.join(Rails.root, "courses", course.name)

    # Create assessment category
    cat = course.assessment_categories.create(name: AUTOGRADE_CATEGORY_NAME)

    # Create assessment
    asmt = cat.assessments.create! do |a|
      a.visible_at = COURSE_START
      a.start_at = COURSE_START
      a.due_at = COURSE_START + (5 + rand(11)).days
      a.end_at = a.due_at + (1 + rand(7)).day
      a.grading_deadline = a.end_at + (1 + rand(7)).day

      a.name = AUTOGRADE_TEMPLATE_NAME
      a.display_name = AUTOGRADE_TEMPLATE_DISPLAY_NAME
      a.handin_directory = AUTOGRADE_TEMPLATE_HANDIN_DIRECTORY
      a.handin_filename = AUTOGRADE_TEMPLATE_HANDIN_FILENAME
      a.has_autograde = true
      a.course_id = course.id

      FileUtils.mkdir_p(File.join(course_dir, a.name, a.handin_directory))
    end

    # Load problem "autograded"
    asmt.problems.create(name: AUTOGRADE_TEMPLATE_PROBLEM_NAME,
                         max_score: AUTOGRADE_TEMPLATE_MAX_SCORE)

    # Copy assessment folder
    FileUtils.cp_r(AUTOGRADE_TEMPLATE_DIR_PATH, course_dir)

    # Copy assessment config
    assessmentConfig_dir = File.join(Rails.root, "assessmentConfig")
    FileUtils.cp(AUTOGRADE_TEMPLATE_CONFIG_PATH, assessmentConfig_dir)

    # Reload config file
    asmt.construct_config_file

    # create all auds
    asmt.create_AUDs_modulo_callbacks

  end

  task :populate, [:name] => :environment do |t, args|
    require "populator" 
  
    args.with_defaults(:name => COURSE_NAME)
    abort("Only use this task in development.") unless Rails.env == "development"
    abort("Course name #{args.name} alread in use. Depopulate or change name.") if Course.where(:name => args.name).first

    # seed rng
    srand 1234

    # to get defaults
    unwanted = lambda { |key, _| key == "created_at" || key == "updated_at" || key == "id" }
    @default_submission = Submission.new.attributes.delete_if &unwanted
    @default_score = Score.new.attributes.delete_if &unwanted
    @default_user = User.new.attributes.delete_if &unwanted

    puts "Creating Course #{args.name} and config file" 
    course = load_course args.name

    puts "Creating Assessment Categories"
    load_assessment_categories course

    puts "Creating Assessments"
    load_assessments course

    puts "Creating Problems"
    load_problems course

    puts "Fast-creating Users"
    load_users course

    puts "Fast-creating Submissions and Scores (might take a while)"
    load_submissions course

    puts "Fast-creating AUDs"
    load_auds course

    puts "Creating configuration files"
    add_assessment_files course

    puts "Creating Autograde Assessment"
    load_autograde_assessment course

    course.reload_config_file

    puts "Population Successful"
  end

  def delete_course course
    if course
      course_dir = File.join(Rails.root, "courses", course.name)
      course_config_dir = File.join(Rails.root, "courseConfig")
      course_config_path = File.join(course_config_dir, "#{course.name}.rb")

      course.destroy

      FileUtils.rm_r(course_dir) if File.exists?(course_dir)
      FileUtils.rm(course_config_path) if File.exists?(course_config_path)
    else
      puts "No course to delete!"
    end
  end

  task :depopulate, [:name] => :environment do |t, args|
    args.with_defaults(:name => COURSE_NAME)
    abort("Only use this task in development.") unless Rails.env == "development"

    course = Course.where(:name => args.name).first

    if course
      puts "Deleting Course along with all associated data (might take a while)"
      delete_course course

      puts "Deleting Users"
      User.delete_all

      puts "Depopulation Successful"
    else
      abort "No course with name #{args.name} found."
    end
  end
end
