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

  def get_students_by_cid(cid)
    cuds = CourseUserDatum.where(course_id: cid, instructor: false, course_assistant: false).all
    cuds.map(&:user)
  end

  def get_students_by_assessment(assessment)
    cid = assessment.course_id
    get_students_by_cid(cid)
  end

  def get_first_cid_by_uid(uid)
    CourseUserDatum.where(user_id: uid).first.course_id
  end

  def get_first_cud_by_uid(uid)
    CourseUserDatum.where(user_id: uid).first.id
  end

  def get_first_aid_by_cud(cud)
    AssessmentUserDatum.where(course_user_datum_id: cud).first.assessment_id
  end

  def get_problems_by_assessment(assessment)
    Problem.where(assessment_id: assessment).all
  end

  def get_first_problem_by_assessment(assessment)
    Problem.where(assessment_id: assessment).first
  end

  def get_first_submission_by_assessment(assessment)
    Submission.where(assessment_id: assessment).first
  end

  def get_handin_path(asmt)
    course = asmt.course
    path = Rails.root.join("courses/#{course.name}/#{asmt.name}")
    Rails.root.join(path, asmt.handin_directory)
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

  def course_att_with_cid(cid, released)
    {
      course_id: cid,
      assessment_id: nil,
      name: "att#{cid}",
      category_name: "General",
      release_at: released ? Time.current : Time.current + 1.day,
      file: fixture_file_upload("attachments/course.txt", "text/plain")
    }
  end

  def create_course_att_with_cid(cid, released)
    FactoryBot.create(:attachment, **course_att_with_cid(cid, released))
  end

  def assess_att_with_cid_aid(cid, aid, released)
    {
      course_id: cid,
      assessment_id: aid,
      name: "att#{cid}--#{aid}",
      category_name: "General",
      release_at: released ? Time.current : Time.current + 1.day,
      file: fixture_file_upload("attachments/assessment.txt", "text/plain")
    }
  end

  def create_assess_att_with_cid_aid(cid, aid, released)
    FactoryBot.create(:attachment, **assess_att_with_cid_aid(cid, aid, released))
  end

  def delete_course_files(course)
    course_path = Rails.root.join("courses", course.name)
    if File.directory?(course_path)
      FileUtils.rm_rf(course_path)
    end
    Assessment.where(course_id: course.id).find_each do |asmt|
      if File.exist?(Rails.root.join("assessmentConfig", asmt.unique_config_file_path))
        File.delete(Rails.root.join("assessmentConfig", asmt.unique_config_file_path))
      end
    end
  end
end
