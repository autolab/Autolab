require "rails_helper"
include ControllerMacros

RSpec.describe CoursesController, type: :controller do
  render_views

  describe "#report_bug" do
    context "when user is Autolab user" do
      u = get_user
      login_as(u)
      cid = get_course_id_by_uid(u.id)
      cname = Course.find(cid).name
      it "renders successfully" do
        get :report_bug, params: { name: cname }
        expect(response).to be_successful
        expect(response.body).to match(/Stuck on a bug/m)
      end
    end

    context "when user is not logged in" do
      u = get_admin
      cid = get_course_id_by_uid(u.id)
      cname = Course.find(cid).name
      it "renders with failure" do
        get :report_bug, params: { name: cname }
        expect(response).not_to be_successful
        expect(response.body).not_to match(/Stuck on a bug/m)
      end
    end
  end

  describe "#user_lookup" do
    context "when user is Autolab admin" do
      u = get_admin
      login_as(u)
      cid = get_course_id_by_uid(u.id)
      cname = Course.find(cid).name
      it "renders successfully" do
        get :user_lookup, params: { name: cname, email: u.email }
        expect(response).to be_successful
        expect(response.body).to match(/first_name/m)
      end
    end

    context "when user is Autolab instructor" do
      u = get_instructor
      login_as(u)
      cid = get_course_id_by_uid(u.id)
      cname = Course.find(cid).name
      it "renders successfully" do
        get :user_lookup, params: { name: cname, email: u.email }
        expect(response).to be_successful
        expect(response.body).to match(/first_name/m)
      end
    end

    context "when user is Autolab user" do
      u = get_user
      login_as(u)
      cid = get_course_id_by_uid(u.id)
      cname = Course.find(cid).name
      it "renders with failure" do
        get :user_lookup, params: { name: cname, email: u.email }
        expect(response).not_to be_successful
        expect(response.body).not_to match(/first_name/m)
      end
    end

    context "when user is not logged in" do
      u = get_admin
      it "renders with failure" do
        get :user_lookup, params: { name: "dummy", email: u.email }
        expect(response).not_to be_successful
        expect(response.body).not_to match(/first_name/m)
      end
    end
  end

  describe "#update_lti_settings" do
    context "when user is autolab instructor" do
      let!(:course) do
        create_course_with_instructor_and_lcd
      end
      before(:each) do
        instructor = get_instructor_by_cid(course.id)
        sign_in(instructor)
      end
      it "updates lti settings" do
        patch :update_lti_settings,
              params: { name: course.name, lcd: { drop_missing_students: "1" } }
        expect(response).to have_http_status(302)
        # need to reload to see changes to model
        course.lti_course_datum.reload
        expect(course.lti_course_datum.drop_missing_students).to equal(true)
      end
    end
  end

  describe "#unlink_course" do
    context "when user is autolab instructor" do
      let!(:course) do
        create_course_with_instructor_and_lcd
      end
      before(:each) do
        instructor = get_instructor_by_cid(course.id)
        sign_in(instructor)
      end
      it "unlinks LTI from course" do
        expect {
          post :unlink_course, params: { name: course.name }
        }.to change(LtiCourseDatum, :count).by(-1)
        expect(response).to have_http_status(302)
        expect(flash[:success]).to be_present
      end
    end

    context "when user is instructor of course with no lcd" do
      let!(:course) do
        FactoryBot.create(:course) do |course|
          user = FactoryBot.create(:user)
          FactoryBot.create(:course_user_datum, course: course, user: user, instructor: true)
          course.lti_course_datum = nil
        end
      end
      before(:each) do
        instructor = get_instructor_by_cid(course.id)
        sign_in(instructor)
      end
      it "fails on unlink" do
        expect {
          post :unlink_course, params: { name: course.name }
        }.to change(LtiCourseDatum, :count).by(0)
        expect(response).to have_http_status(302)
        expect(flash[:error]).to be_present
      end
    end
  end

  describe "#download_roster" do
    context "when user is autolab instructor" do
      let!(:course) do
        create_course_with_many_students
      end
      it "downloads roster" do
        instructor = get_instructor_by_cid(course.id)
        sign_in(instructor)
        get :download_roster, params: { name: course.name }, format: CSV
        expect(response).to have_http_status(200)
        expect(response.body).to match(/#{course.name}/m)
        # some of these fields aren't necessarily defined
        # but check for all of them to be in CSV
        CourseUserDatum.where(course: course) do |cud|
          page.should have_content cud.user.email
          page.should have_content cud.user.last_name
          page.should have_content cud.user.first_name
          page.should have_content cud.user.school
          page.should have_content cud.major
          page.should have_content cud.lecture
          page.should have_content cud.section
          page.should have_content cud.year
          page.should have_content cud.grade_policy
        end
      end
    end
  end

  describe "#add_users_from_emails" do
    context "when instructor" do
      let!(:course) do
        create_course_with_many_students
      end
      let!(:users_to_add) do
        FactoryBot.create_list(:user, 10)
      end
      let!(:unused_emails) do
        Array.new(10) { |elem| "unused#{elem}@example.org" }
      end
      before(:each) do
        instructor = get_instructor_by_cid(course.id)
        sign_in(instructor)
      end

      it "adds users as course assistants successfully" do
        users_emails = ""
        # test various input methods of emails and names
        users_to_add.each_with_index do |user, i|
          users_emails += case i % 4
                          when 0
                            "#{user.email}\n"
                          when 1
                            "#{user.first_name} <#{user.email}>\n"
                          when 2
                            "#{user.first_name} middle #{user.last_name} <#{user.email}>\n"
                          else
                            "#{user.last_name} <#{user.email}>\n"
                          end
        end
        post :add_users_from_emails,
             params: { name: course.name, user_emails: users_emails, role: "ca" }
        expect(response).to have_http_status(302)
        expect(flash[:success]).to be_present
      end

      it "adds users as instructors successfully" do
        users_emails = ""
        users_to_add.each do |user|
          users_emails += "#{user.email}\n"
        end
        post :add_users_from_emails,
             params: { name: course.name, user_emails: users_emails, role: "instructor" }
        expect(response).to have_http_status(302)
        expect(flash[:success]).to be_present
      end

      it "adds users as students successfully" do
        users_emails = ""
        users_to_add.each do |user|
          users_emails += "#{user.email}\n"
        end
        post :add_users_from_emails,
             params: { name: course.name, user_emails: users_emails, role: "student" }
        expect(response).to have_http_status(302)
        expect(flash[:success]).to be_present
      end

      it "adds new users as course assistants successfully" do
        instructor = get_instructor_by_cid(course.id)
        sign_in(instructor)
        emails = ""
        unused_emails.each_with_index do |email, i|
          emails += case i % 4
                    when 0
                      "#{email}\n"
                    when 1
                      "#test <#{email}>\n"
                    when 2
                      "#test middle last <#{email}>\n"
                    else
                      "last <#{email}>\n"
                    end
        end
        expect {
          post :add_users_from_emails, params:
            { name: course.name, user_emails: emails, role: "ca" }
        }.to change(CourseUserDatum.where(course: course, course_assistant: true), :count).by(10)
        expect(response).to have_http_status(302)
        expect(flash[:success]).to be_present
      end

      it "fails on invalid email" do
        emails = "@example.com\n"
        post :add_users_from_emails, params:
          { name: course.name, user_emails: emails, role: "ca" }
        expect(response).to have_http_status(302)
        expect(flash[:error]).to be_present
      end

      it "fails when no params provided" do
        post :add_users_from_emails, params: { name: course.name }
        expect(response).to have_http_status(302)
        expect(flash[:error]).to be_present
      end

      it "fails when role is invalid" do
        users_emails = ""
        users_to_add.each do |user|
          users_emails += "#{user.email}\n"
        end
        post :add_users_from_emails, params:
          { name: course.name, user_emails: users_emails, role: "not_role" }
        expect(response).to have_http_status(302)
        expect(flash[:error]).to be_present
      end

      it "handles error during user creation" do
        allow(User).to receive(:roster_create).and_raise(StandardError)
        users_emails = ""
        unused_emails.each do |email|
          users_emails += "#{email}\n"
        end
        post :add_users_from_emails, params:
          { name: course.name, user_emails: users_emails, role: "ca" }
        expect(response).to have_http_status(302)
        expect(flash[:error]).to be_present
        expect(flash[:error]).to match(/Error: StandardError/m)
      end

      it "handles nil during user creation" do
        allow(User).to receive(:roster_create).and_return(nil)
        users_emails = ""
        unused_emails.each do |email|
          users_emails += "#{email}\n"
        end
        post :add_users_from_emails, params:
          { name: course.name, user_emails: users_emails, role: "ca" }
        expect(response).to have_http_status(302)
        expect(flash[:error]).to be_present
        expect(flash[:error]).to match(/Error: User (.+) could not be created./m)
      end

      it "handles cud error" do
        allow_any_instance_of(CourseUserDatum).to receive(:save).and_return(nil)
        users_emails = ""
        unused_emails.each do |email|
          users_emails += "#{email}\n"
        end
        post :add_users_from_emails, params:
          { name: course.name, user_emails: users_emails, role: "ca" }
        expect(response).to have_http_status(302)
        expect(flash[:error]).to be_present
        expect(flash[:error]).to match(/Error: Users could not be added to course./m)
      end
    end
  end
end
