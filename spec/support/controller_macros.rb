require "tempfile"

module ControllerMacros
  def get_admin
    admins = User.where(administrator: true)
    admins.offset(rand(admins.count)).first
  end

  def get_instructor
    instructorCUDs = CourseUserDatum.where(instructor: true)
    instructorCUDs.offset(rand(instructorCUDs.count)).first.user
  end

  def get_course_assistant
    caCUDs = CourseUserDatum.where(course_assistant: true)
    caCUDs.offset(rand(caCUDs.count)).first.user
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

  def create_scheduler_with_cid(cid)
    # Prepare the updater script for scheduler to run
    update_script_path = Rails.root.join("tmp/testscript.rb")
    File.open(update_script_path, "w") do |f|
      f.write("module Updater def self.update(foo) 0 end end")
    end
    s = Course.find(cid).scheduler.new(action: "tmp/testscript.rb",
                                       interval: 86_400, next: Time.now)
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
        path=Rails.root.join("attachments", File.basename(course_att_file)), content_type="text/plain",
        tempfile=Tempfile.new("attach.tmp"))
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
end
