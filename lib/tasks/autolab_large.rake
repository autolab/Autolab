require "fileutils"

namespace :autolab_large do
  COURSE_NAME = "LargeCourse"
  USER_COUNT = 400
  ASSESSMENT_CATEGORIES = ["Homework", "Lab", "Quiz"]
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

  HUGE_FEEDBACK = "Lorem ipsum dolor sit amet, consectetur adipiscing elit. Cras imperdiet condimentum sem sit amet gravida. Proin mattis, mi porttitor lacinia tempor, tellus mauris sodales enim, in venenatis nunc libero a libero. Etiam cursus lectus luctus ipsum commodo dictum. Vestibulum erat tellus, volutpat vel augue id, lacinia laoreet mauris. Morbi congue et metus vel mollis. Curabitur fringilla ipsum eget nisi ullamcorper bibendum. Curabitur pretium efficitur sem, ut congue nulla. Mauris turpis lacus, dapibus at enim semper, tempus commodo ante.

Nullam vitae nulla sagittis, aliquam urna nec, tincidunt tellus. Nam at lectus egestas, convallis dui et, rhoncus risus. Ut dictum nec diam eu pellentesque. Nullam vitae nulla et purus vehicula bibendum nec nec diam. Sed posuere mi a lacus maximus accumsan. Morbi ac facilisis nisl. Praesent ut volutpat nisi. Nam consequat, risus at mollis maximus, nisl ex maximus mi, ut auctor neque turpis convallis nulla. Nullam eros diam, efficitur id magna sit amet, commodo facilisis purus. Fusce imperdiet, felis venenatis maximus mattis, est quam dapibus magna, at congue magna neque at sem. Nullam vel varius risus. Curabitur vehicula sodales suscipit. Donec purus neque, dapibus at massa non, pulvinar sodales diam. Nullam dictum tortor orci, a finibus nisl fringilla ac. Morbi scelerisque id turpis eleifend egestas. Pellentesque semper congue sapien posuere suscipit.

Nam a imperdiet ex. Duis sollicitudin ipsum metus, lacinia congue mauris bibendum eu. Maecenas egestas consectetur arcu a porta. Curabitur ut pretium dui. Donec efficitur quis dui id tincidunt. Donec magna arcu, sollicitudin ac cursus ac, tempus sed lectus. Cras ut convallis eros. Suspendisse congue turpis nec aliquam vulputate. Sed in venenatis nisl. Curabitur consectetur libero enim. Suspendisse augue lacus, auctor quis rhoncus id, dignissim eu massa. Nunc gravida, magna eget ornare sodales, mauris lacus aliquam diam, id viverra eros turpis in orci. In vulputate lobortis feugiat. Proin eu leo eget neque dictum facilisis. Maecenas interdum erat sed turpis gravida dignissim.

Phasellus ligula ex, consectetur eget vestibulum congue, finibus eget quam. Fusce ornare libero eu scelerisque tincidunt. Fusce mollis dolor id turpis cursus, eu maximus augue ultrices. Praesent eu egestas nibh, ac egestas risus. Curabitur cursus erat non sagittis dapibus. Vestibulum venenatis enim ut quam aliquam pretium. Maecenas consequat aliquam tincidunt. Aliquam quis congue metus. Sed aliquam tortor augue, a sodales augue lobortis ut. Phasellus et ex ac dui convallis consectetur. Nam nec mauris id lacus tristique lobortis id quis dolor. Cras sed ornare felis. Donec consequat sapien vel sapien aliquet vulputate. Suspendisse auctor enim vitae ante ultricies, sed luctus est vehicula. Morbi commodo vehicula ultricies. Curabitur convallis fermentum urna non bibendum.

Morbi aliquet velit et tincidunt vehicula. Phasellus ullamcorper mollis lectus in vehicula. Aliquam semper elit vel tempor sagittis. Vivamus velit ante, placerat at venenatis vitae, dictum non libero. Curabitur velit urna, aliquam a dignissim eget, posuere sed purus. Vestibulum pellentesque dui ac justo sodales, in commodo magna fringilla. Aliquam aliquam ac ante ut vehicula. Proin eleifend commodo hendrerit. Aenean at libero dui. Nunc purus ex, feugiat ut ligula quis, volutpat rutrum quam. Praesent ac nisl consequat, commodo nisl eu, tincidunt eros. Praesent molestie gravida velit eget pellentesque.

Nulla in blandit nunc, ac hendrerit enim. Praesent tincidunt sapien in mi scelerisque, porttitor dapibus magna mollis. Pellentesque sit amet lectus at nisl ultrices interdum quis et quam. Praesent imperdiet metus et augue tempor, a tempus elit pellentesque. Lorem ipsum dolor sit amet, consectetur adipiscing elit. Nam aliquam luctus urna at semper. Ut eget finibus dui, et aliquam neque. Aliquam erat volutpat. Donec turpis diam, viverra non placerat ut, consequat vel arcu. Quisque rutrum ante eu mauris vehicula pretium. Proin scelerisque sem nec facilisis tincidunt. Ut lacinia massa non elit viverra blandit. Cras blandit tellus sit amet dolor commodo, in luctus nibh ullamcorper. Aliquam porttitor est et finibus rhoncus. Sed auctor lorem ut augue rhoncus lacinia. Morbi ligula felis, consectetur eu aliquam ac, auctor quis ante.

Cras at iaculis diam. Quisque a felis eu augue tincidunt convallis id vel erat. Donec rhoncus eros nec lorem malesuada, nec elementum arcu congue. Donec a dapibus odio. Phasellus non leo augue. Aenean id erat at purus eleifend scelerisque sed ornare dolor. Integer ac odio dapibus augue aliquam condimentum.

Vestibulum eget nunc efficitur, semper arcu nec, scelerisque erat. Maecenas cursus leo quis libero mattis dapibus in nec magna. Morbi ullamcorper elementum tellus vel consequat. Nullam ut odio leo. Suspendisse fermentum volutpat augue, eu auctor felis pharetra vitae. Sed ligula neque, ultricies quis ipsum ut, laoreet suscipit ipsum. Duis faucibus interdum orci eget blandit. Class aptent taciti sociosqu ad litora torquent per conubia nostra, per inceptos himenaeos.

Vivamus efficitur tellus ut venenatis bibendum. Mauris efficitur a massa sit amet placerat. Vivamus lorem turpis, ultricies vel felis sed, scelerisque ultricies erat. Nulla et aliquam erat, in blandit ante. Fusce porttitor risus ut tortor dapibus, ac lobortis nibh tempor. Aenean vel sem ut enim sollicitudin faucibus eget id sem. Integer dignissim augue sed sem congue consequat. Quisque in nisl tortor. Sed at semper turpis, vitae scelerisque nisi. Maecenas sodales pellentesque turpis convallis posuere. Quisque ut tincidunt nisi, id ultricies turpis. Sed blandit ligula non mi aliquam, sed tempor metus sagittis. Sed vel lobortis lorem.

In id sem facilisis, lacinia libero scelerisque, sodales nulla. Sed velit felis, pharetra eu mauris id, ullamcorper maximus metus. Mauris a quam sed lorem bibendum dictum. Nam ex sapien, pellentesque ac nibh id, euismod efficitur sem. Vestibulum ante ipsum primis in faucibus orci luctus et ultrices posuere cubilia Curae; Cras efficitur imperdiet mauris, eget condimentum tortor convallis at. Vivamus non pellentesque dolor. "

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

  def load_assessments course
    course_dir = File.join(Rails.root, "courses", course.name)
    ASSESSMENT_CATEGORIES.each do |cat|

      # start date for this category
      start = COURSE_START + rand(20).day

      ASSESSMENT_COUNT.times do |i|
        course.assessments.create do |a|
          a.category_name = cat
          
          a.visible_at = start 
          a.start_at = start
          a.due_at = start + (5 + rand(11)).days          # 5-15d after start date
          a.end_at = a.due_at + (1 + rand(7)).day   # 1d-1w after the due date
          a.grading_deadline = a.end_at + (1 + rand(7)).day   # 1-7d after submit deadline 

          a.name = "#{cat}#{i.to_s}".downcase
          a.display_name = "#{cat} #{i.to_s}"
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
      :course_assistant => true,

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
        # random 50 char string along with fixed chunk of feedback
        score.feedback = (0...50).map { ('a'..'z').to_a[rand(26)] }.join + HUGE_FEEDBACK
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

    # Create assessment
    asmt = course.assessments.create! do |a|
      a.category_name = AUTOGRADE_CATEGORY_NAME
      
      a.visible_at = COURSE_START
      a.start_at = COURSE_START
      a.due_at = COURSE_START + (5 + rand(11)).days
      a.end_at = a.due_at + (1 + rand(7)).day
      a.grading_deadline = a.end_at + (1 + rand(7)).day

      a.name = AUTOGRADE_TEMPLATE_NAME
      a.display_name = AUTOGRADE_TEMPLATE_DISPLAY_NAME
      a.handin_directory = AUTOGRADE_TEMPLATE_HANDIN_DIRECTORY
      a.handin_filename = AUTOGRADE_TEMPLATE_HANDIN_FILENAME
      a.course_id = course.id

      FileUtils.mkdir_p(File.join(course_dir, a.name, a.handin_directory))
    end

    # Load autograding properties
    Autograder.create! do |autograder|
      autograder.assessment_id = asmt.id
      autograder.autograde_image = "rhel.img"
      autograder.autograde_timeout = 180
      autograder.release_score = true
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
    asmt.load_config_file
  end

  task :populate, [:name] => :environment do |t, args|
    require "populator" 
  
    args.with_defaults(:name => COURSE_NAME)
    abort("Only use this task in development or test.") unless ["development", "test"].include? Rails.env
    # If course exists, in `dev` aborts; in `test` overwrites.
    if Course.where(:name => args.name).first
      if Rails.env == "development"
        abort("Course name #{args.name} alread in use. Depopulate or change name.")
      else
        Rake::Task["autolab:depopulate"].invoke(args.name)
        Rake::Task["db:reset"].invoke()
      end
    end

    # seed rng
    srand 1234

    # to get defaults
    unwanted = lambda { |key, _| key == "created_at" || key == "updated_at" || key == "id" }
    @default_submission = Submission.new.attributes.delete_if &unwanted
    @default_score = Score.new.attributes.delete_if &unwanted
    @default_user = User.new.attributes.delete_if &unwanted

    puts "Creating Course #{args.name} and config file" 
    course = load_course args.name

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
    abort("Only use this task in development or test.") unless ["development", "test"].include? Rails.env

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

