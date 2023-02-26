require "tempfile"

module ControllerMacros
  def get_admin
    admins = User.where(administrator: true)
    admins.offset(rand(admins.count)).first
  end

  def get_instructor
    instructorCUDs = CourseUserDatum.joins(:user).where("users.administrator" => false,
                                                        :instructor => true)
    instructorCUDs.offset(rand(instructorCUDs.count)).first.user
  end

  def get_instructor_by_cid(cid)
    instructorCUDs = CourseUserDatum.where(course_id: cid, instructor: true)
    instructorCUDs.offset(rand(instructorCUDs.count)).first.user
  end

  def get_course_assistant
    caCUDs = CourseUserDatum.where(course_assistant: true)
    caCUDs.offset(rand(caCUDs.count)).first.user
  end

  def get_course_assistant_only
    CourseUserDatum.where(course_assistant: true, instructor: false).first.user
  end

  def get_user
    users = CourseUserDatum.joins(:user).where("users.administrator" => false,
                                               :instructor => false,
                                               :course_assistant => false)
    users.offset(rand(users.count)).first.user
  end

  def login_admin
    login_as(get_admin)
  end

  def login_instructor
    login_as(get_instructor)
  end

  def login_course_assistant
    login_as(get_course_assistant)
  end

  def login_user
    login_as(get_user)
  end

  def login_as(u)
    before(:each) do
      @request.env["devise.mapping"] = Devise.mappings[:user]
      sign_in u
    end
  end

  def get_course_id_by_uid(uid)
    CourseUserDatum.where(user_id: uid).first.course_id
  end

  def get_first_cud_by_uid(uid)
    CourseUserDatum.where(user_id: uid).first.id
  end

  def get_first_aid_by_cud(cud)
    AssessmentUserDatum.where(course_user_datum_id: cud).first.assessment_id
  end

  # create user and add to given course as a course assistant
  def create_ca_for_course(cid, email, first_name, last_name, password)
    user = User.new(email: email, first_name: first_name, last_name: last_name, password: password,
                    administrator: false, school: "My School", major: "CS", year: "4")
    user.skip_confirmation!
    user.save!
    CourseUserDatum.create!({
                              user: user,
                              course: cid,

                              course_number: "AutoPopulated",
                              lecture: "1",
                              section: "A",
                              dropped: false,

                              instructor: false,
                              course_assistant: true,

                              nickname: "courseassistant"
                            })
    user
  end

  def get_first_course
    Course.first
  end

  def create_scheduler_with_cid(cid)
    # Prepare the updater script for scheduler to run
    update_script_path = Rails.root.join("tmp/testscript.rb")
    File.open(update_script_path, "w") do |f|
      f.write("module Updater def self.update(foo) 0 end end")
    end
    s = Course.find(cid).scheduler.new(action: "tmp/testscript.rb",
                                       interval: 86_400, next: Time.zone.now)
    s.save
    s
  end

  def create_course_att_with_cid(cid)
    # Prepare course attachment file
    course_att_file = Rails.root.join("attachments/testattach.txt")
    File.open(course_att_file, "w") do |f|
      f.write("Course attachment file")
    end
    att = Attachment.new(course_id: cid, assessment_id: nil,
                         name: "att#{cid}",
                         released: true)

    att.file = Rack::Test::UploadedFile.new(
      Rails.root.join("attachments/#{File.basename(course_att_file)}"),
      "text/plain",
      Tempfile.new("attach.tmp")
    )
    att.save
    att
  end

  def create_assess_att_with_cid_aid(cid, aid)
    # Prepare assessment attachment file
    assess_att_file = Rails.root.join("attachments/assessattach.txt")
    File.open(assess_att_file, "w") do |f|
      f.write("Assessment attachment file")
    end
    att = Attachment.new(course_id: cid, assessment_id: aid,
                         name: "att#{cid}-#{aid}", filename: assess_att_file,
                         released: true, mime_type: "text/plain")
    att.file = File.open(assess_att_file, "w")
    att.save
    att
  end

  # create a course which has an instructor and lcd attached
  def create_course_with_instructor_and_lcd
    FactoryBot.create(:course) do |course|
      user = FactoryBot.create(:user)
      FactoryBot.create(:course_user_datum, course: course, user: user, instructor: true)
      FactoryBot.create(:lti_course_datum, course_id: course.id)
    end
  end

  # Generic function that creates a sample class
  # create course with unique CUDs (unique student users)
  def create_course_with_many_students(students_count: 3, asmt_name: "testassessment",
                                       instructor_user: nil)
    if asmt_name =~ /[^a-z0-9]/
      raise ArgumentError("Assessment name must contain only lowercase and digits")
    end

    course = FactoryBot.create(:course) do |new_course|
      # create assessment directory
      path = Rails.root.join("courses/#{new_course.name}/#{asmt_name}")
      FileUtils.mkdir_p(path)
      asmt = FactoryBot.create(:assessment, course: new_course, name: asmt_name)
      asmt.construct_default_config_file
    end

    admin_user = FactoryBot.create(:user, administrator: true)
    instructor_user ||= FactoryBot.create(:user)
    course_assistant_user = FactoryBot.create(:user)

    FactoryBot.create(:course_user_datum, course: course, user: instructor_user, instructor: true)

    FactoryBot.create(:course_user_datum, course: course,
                                          user: course_assistant_user,
                                          instructor: false, course_assistant: true)

    students = FactoryBot.create_list(:student, students_count, course: course).each do |cud|
      cud.user = FactoryBot.create(:user)
    end

    assessment = Assessment.where(course: course, name: asmt_name).first

    { course: course, admin_user: admin_user,
      instructor_user: instructor_user, course_assistant_user: course_assistant_user,
      students_cud: students, assessment: assessment }
  end

  def create_asssessments_with_submissions_for_course(course)
    assessment = FactoryBot.create(:assessment, course: course)
    problem = FactoryBot.create(:problem, assessment: assessment)

    # for each student in the course, create a submission
    course.course_user_data.each do |cud|
      FactoryBot.create(:submission, problem: problem, course_user_datum: cud)
    end

    { assessment: assessment, problem: problem, submissions: submissions }
  end
end
