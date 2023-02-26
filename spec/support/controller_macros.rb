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

  def get_first_aid_by_cid(cid)
    Assessment.where(course_id: cid).first.id
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

  def create_course_att_with_cid(cid, released)
    FactoryBot.create(:attachment,
                      course_id: cid,
                      assessment_id: nil,
                      name: "att#{cid}",
                      released: released,
                      file: fixture_file_upload("attachments/course.txt", "text/plain"))
  end

  def create_assess_att_with_cid_aid(cid, aid, released)
    FactoryBot.create(:attachment,
                      course_id: cid,
                      assessment_id: aid,
                      name: "att#{cid}--#{aid}",
                      released: released,
                      file: fixture_file_upload("attachments/assessment.txt", "text/plain"))
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
  def create_course_with_many_students(students_count: 3)
    course = FactoryBot.create(:course)

    admin_user = FactoryBot.create(:user, administrator: true)
    instructor_user = FactoryBot.create(:user)
    course_assistant_user = FactoryBot.create(:user)

    FactoryBot.create(:course_user_datum, course: course, user: instructor_user, instructor: true)

    FactoryBot.create(:course_user_datum, course: course,
                                          user: course_assistant_user,
                                          instructor: false, course_assistant: true)

    students = FactoryBot.create_list(:student, students_count, course: course).each do |cud|
      cud.user = FactoryBot.create(:user)
    end

    { course: course, admin_user: admin_user,
      instructor_user: instructor_user, course_assistant_user: course_assistant_user,
      students_cud: students }
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
