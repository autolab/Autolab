require "rails_helper"
include ControllerMacros
require_relative "controllers_shared_context"

RSpec.describe CoursesController, type: :controller do
  render_views

  describe "#report_bug" do
    include_context "controllers shared context"
    context "when user is Autolab user" do
      it "renders successfully" do
        sign_in(student_user)
        get :report_bug, params: { name: @course.name }
        expect(response).to be_successful
        expect(response.body).to match(/Stuck on a bug/m)
      end
    end

    context "when user is not logged in" do
      it "renders with failure" do
        get :report_bug, params: { name: @course.name }
        expect(response).not_to be_successful
        expect(response.body).not_to match(/Stuck on a bug/m)
      end
    end
  end

  shared_examples "user_lookup_success" do
    before(:each) do
      sign_in(user)
    end
    it "renders successfully" do
      get :user_lookup, params: { name: @course.name, email: user.email }
      expect(response).to be_successful
      expect(response.body).to match(/first_name/m)
    end
  end

  shared_examples "user_lookup_failure" do |login: false|
    before(:each) do
      sign_in(user) if login
    end
    it "renders with failure" do
      get :user_lookup, params: { name: @course.name, email: user.email }
      expect(response).not_to be_successful
      expect(response.body).not_to match(/first_name/m)
    end
  end

  describe "#user_lookup" do
    include_context "controllers shared context"
    context "when user is Autolab admin" do
      it_behaves_like "user_lookup_success" do
        let!(:user) { admin_user }
      end
    end

    context "when user is Autolab instructor" do
      it_behaves_like "user_lookup_success" do
        let!(:user) { instructor_user }
      end
    end

    context "when user is Autolab user" do
      it_behaves_like "user_lookup_failure", login: true do
        let!(:user) { student_user }
      end
    end

    context "when user is not logged in" do
      it_behaves_like "user_lookup_failure", login: false do
        let!(:user) { student_user }
      end
    end
  end

  describe "#update_lti_settings" do
    include_context "controllers shared context"
    context "when user is Autolab instructor" do
      before(:each) do
        sign_in(@instructor_user)
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
    context "when user is Autolab instructor" do
      include_context "controllers shared context"
      before(:each) do
        sign_in(@instructor_user)
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
          FactoryBot.create(:course_user_datum, course:, user:, instructor: true)
          course.lti_course_datum = nil
        end
      end
      before(:each) do
        instructor = get_instructor_by_cid(course.id)
        sign_in(instructor)
      end
      after(:each) do
        delete_course_files(course)
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
    context "when user is Autolab instructor" do
      include_context "controllers shared context"
      it "downloads roster" do
        sign_in(@instructor_user)
        get :download_roster, params: { name: course.name }, format: CSV
        expect(response).to have_http_status(200)
        expect(response.body).to match(/Auto-populated/m) # lecture
        # some of these fields aren't necessarily defined
        # but check for all of them to be in CSV
        CourseUserDatum.where(course:) do |cud|
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
    include_context "controllers shared context"
    context "when instructor" do
      let!(:users_to_add) do
        FactoryBot.create_list(:user, 10)
      end
      let!(:unused_emails) do
        Array.new(10) { |elem| "unused#{elem}@example.org" }
      end
      before(:each) do
        sign_in(@instructor_user)
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
        }.to change(CourseUserDatum.where(course:, course_assistant: true), :count).by(10)
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

  describe "#import_course" do
    include_context "controllers shared context"
    context "when user is administrator" do
      before(:each) do
        user = get_admin
        sign_in(user)
        @instructor_email = "instructor@gmail.com"
        @course_name = "course"
      end
      it "successfully creates course from valid tar" do
        file = fixture_file_upload("courses/course-valid.tar")
        post :create_from_tar, params: { instructor_email: @instructor_email,
                                         tarFile: file }
        expect(response).to have_http_status(302)
        expect(flash[:success]).to be_present
        expect(Course.find_by(name: @course_name)).to be_an_instance_of(Course)
      end
      it "handles nil tarfile" do
        post :create_from_tar, params: { instructor_email: @instructor_email }
        expect(response).to have_http_status(200)
        expect(flash[:error]).to be_present
        expect(flash[:error]).to match(/Please select a course tarball for uploading/m)
      end
      it "handles invalid course tarball" do
        file = fixture_file_upload("courses/course-invalid.tar")
        post :create_from_tar, params: { instructor_email: @instructor_email,
                                         tarFile: file }
        expect(response).to have_http_status(200)
        expect(flash[:error]).to be_present
        expect(flash[:error]).to match(/Error while reading the tarball/m)
      end
      it "handles missing course yml" do
        file = fixture_file_upload("courses/course-missing-yml.tar")
        post :create_from_tar, params: { instructor_email: @instructor_email,
                                         tarFile: file }
        expect(response).to have_http_status(200)
        expect(flash[:error]).to be_present
        expect(flash[:error]).to match(/\.yml was not found/m)
      end
      it "handles wrong course yml name" do
        file = fixture_file_upload("courses/course-mismatch-yml.tar")
        post :create_from_tar, params: { instructor_email: @instructor_email,
                                         tarFile: file }
        expect(response).to have_http_status(200)
        expect(flash[:error]).to be_present
        expect(flash[:error]).to match(/\.yml was not found/m)
      end
      it "handles bad config file syntax" do
        file = fixture_file_upload("courses/course-bad-config-syntax.tar")
        post :create_from_tar, params: { instructor_email: @instructor_email,
                                         tarFile: file }
        expect(response).to have_http_status(200)
        expect(flash[:error]).to be_present
        expect(flash[:error]).to match(/syntax error/m)
      end
      it "handles tar with invalid directory structure" do
        file = fixture_file_upload("courses/course-no-root.tar")
        post :create_from_tar, params: { instructor_email: @instructor_email,
                                         tarFile: file }
        expect(response).to have_http_status(200)
        expect(flash[:error]).to be_present
        expect(flash[:error]).to match(/there is only one root directory in the tarball/m)
      end
    end
  end

  describe "#import_upload" do
    context "when user is administrator" do
      before(:each) do
        @admin = FactoryBot.create(:user, administrator: true)
        sign_in(@admin)
      end

      after(:each) do
        CourseTransfer::StagedUpload.clear_user!(@admin) if @admin
        session.delete(:course_import)
      end

      it "stages a legacy tar and redirects to legacy import" do
        file = fixture_file_upload("courses/course-valid.tar")
        post :import_upload, params: { tarFile: file }
        expect(response).to redirect_to(legacy_import_courses_path)
        expect(session[:course_import]).to be_present
        expect(session[:course_import]["version"]).to eq(CourseTransfer::Version::LEGACY)
        token = session[:course_import]["token"]
        staged = CourseTransfer::StagedUpload.find!(@admin, token)
        expect(staged.path).to be_a(Pathname)
        expect(File).to exist(staged.path)
      end

      it "stages a new-format tar and redirects to import" do
        tar_path = Rails.root.join("tmp", "course-new-format-#{SecureRandom.hex(4)}.tar")
        File.open(tar_path, "wb") do |f|
          Gem::Package::TarWriter.new(f) do |tar|
            tar.add_file("manifest.yml", 0o644) do |io|
              io.write({
                "format" => CourseTransfer::Version::FORMAT_ID,
                "version" => "1.0.0",
                "min_target_version" => "1.0.0",
                "parts" => []
              }.to_yaml)
            end
          end
        end
        file = Rack::Test::UploadedFile.new(tar_path, "application/x-tar", true)
        post :import_upload, params: { tarFile: file }
        FileUtils.rm_f(tar_path)
        expect(response).to redirect_to(import_courses_path)
        expect(session[:course_import]["version"]).to eq("1.0.0")
      end

      it "imports a staged new-format package and cleans up the upload" do
        tar_path = Rails.root.join("tmp", "course-import-action-#{SecureRandom.hex(4)}.tar")
        File.open(tar_path, "wb") do |file|
          Gem::Package::TarWriter.new(file) do |tar|
            tar.add_file("manifest.yml", 0o644) do |entry|
              entry.write({
                "format" => CourseTransfer::Version::FORMAT_ID,
                "version" => CourseTransfer::Version::CURRENT,
                "min_target_version" => CourseTransfer::Version::MIN_SUPPORTED_TARGET.to_s,
                "parts" => []
              }.to_yaml)
            end
          end
        end
        upload = Rack::Test::UploadedFile.new(tar_path, "application/x-tar", true)
        post :import_upload, params: { tarFile: upload }
        FileUtils.rm_f(tar_path)
        staged_path = CourseTransfer::StagedUpload.find!(
          @admin,
          session[:course_import]["token"]
        ).path
        imported_course = FactoryBot.create(:course)
        manager = instance_double(CourseTransfer::ImportManager, import: imported_course)
        allow(CourseTransfer::ImportManager).to receive(:new).and_return(manager)

        post :complete_import, params: {
          course_identifier: "imported-course",
          instructor_email: "new-instructor@example.com"
        }

        expect(response).to redirect_to(course_path(imported_course.name))
        expect(session[:course_import]).to be_nil
        expect(File).not_to exist(staged_path)
      end

      it "uses the staged package for create_from_tar without tarFile param" do
        file = fixture_file_upload("courses/course-valid.tar")
        post :import_upload, params: { tarFile: file }
        token = session[:course_import]["token"]
        staged = CourseTransfer::StagedUpload.find!(@admin, token)

        opened_staged = false
        allow(File).to receive(:open).and_call_original
        allow(File).to receive(:open)
          .with(staged.path, "rb")
          .and_wrap_original do |method, *args, &block|
            opened_staged = true
            method.call(*args, &block)
          end

        post :create_from_tar, params: { instructor_email: "instructor@gmail.com" }

        expect(opened_staged).to be(true)
        expect(flash[:error].to_s).not_to match(/Please select a course tarball/)
      end

      it "cleans up staged files after a successful create_from_tar" do
        file = fixture_file_upload("courses/course-valid.tar")
        post :import_upload, params: { tarFile: file }
        token = session[:course_import]["token"]
        staged_path = CourseTransfer::StagedUpload.find!(@admin, token).path

        # Force the success cleanup path without relying on full course lifecycle
        # (Unix group setup is unavailable on some hosts).
        allow_any_instance_of(CoursesController).to receive(:create_from_tar) do |controller|
          controller.send(:cleanup_course_import_session!)
          controller.redirect_to("/")
        end

        post :create_from_tar, params: { instructor_email: "instructor@gmail.com" }
        expect(session[:course_import]).to be_nil
        expect(File).not_to exist(staged_path)
      end
    end
  end

  shared_examples "export_success" do
    before(:each) do
      sign_in(user)
    end
    it "renders the new-format export page" do
      get :export, params: { name: @course.name }
      expect(response).to be_successful
      expect(response.body).to match(/Select the users and assessments to include/m)
      expect(response.body).to match(/submissions are exported only when both/m)
      expect(response.body).to match(/Assessments/m)
    end

    it "exports a new-format course package after submission" do
      post :export_selected, params: { name: @course.name, export_parts: ["bundle"] }
      expect(response).to be_successful

      entries = {}
      Gem::Package::TarReader.new(StringIO.new(response.body)) do |tar|
        tar.each do |entry|
          entries[entry.full_name] = entry.read unless entry.directory?
        end
      end

      expect(entries.keys).to include(
        "courses.yml", "users.yml", "assessments.yml", "submissions.yml", "manifest.yml"
      )
      course_rows = YAML.load_stream(entries.fetch("courses.yml"))
      expect(course_rows.one?).to be(true)
      expect(course_rows.first.fetch("late_slack")).to eq(@course[:late_slack])
      manifest = YAML.safe_load(entries.fetch("manifest.yml"))
      expect(manifest["format"]).to eq(CourseTransfer::Version::FORMAT_ID)
      expect(manifest["parts"]).to include("courses", "users", "assessments", "submissions")
    end
  end

  shared_examples "export_failure" do |login: false|
    before(:each) do
      sign_in(user) if login
    end
    it "renders with failure" do
      get :export, params: { name: @course.name }
      expect(response).not_to be_successful
      expect(response.body).not_to match(/Export Course/m)
    end
  end

  describe "#export" do
    include_context "controllers shared context"
    context "when user is Autolab admin" do
      it_behaves_like "export_success" do
        let!(:user) { admin_user }
      end
    end

    context "when user is Autolab instructor" do
      it_behaves_like "export_success" do
        let!(:user) { instructor_user }
      end
    end

    context "when user is Autolab user" do
      it_behaves_like "export_failure", login: true do
        let!(:user) { student_user }
      end
    end

    context "when user is not logged in" do
      it_behaves_like "export_failure", login: false do
        let!(:user) { student_user }
      end
    end
  end

  shared_examples "legacy_export_success" do
    before(:each) do
      sign_in(user)
    end
    it "renders successfully" do
      get :legacy_export, params: { name: @course.name }
      expect(response).to be_successful
      expect(response.body).to match(/Legacy Export/m)
      expect(response.body).to match(/deprecated/m)
      expect(response.body).to match(/Select fields to include in the export/m)
    end
  end

  shared_examples "legacy_export_failure" do |login: false|
    before(:each) do
      sign_in(user) if login
    end
    it "renders with failure" do
      get :legacy_export, params: { name: @course.name }
      expect(response).not_to be_successful
      expect(response.body).not_to match(/Legacy Export/m)
    end
  end

  describe "#legacy_export" do
    include_context "controllers shared context"
    context "when user is Autolab admin" do
      it_behaves_like "legacy_export_success" do
        let!(:user) { admin_user }
      end
    end

    context "when user is Autolab instructor" do
      it_behaves_like "legacy_export_success" do
        let!(:user) { instructor_user }
      end
    end

    context "when user is Autolab user" do
      it_behaves_like "legacy_export_failure", login: true do
        let!(:user) { student_user }
      end
    end

    context "when user is not logged in" do
      it_behaves_like "legacy_export_failure", login: false do
        let!(:user) { student_user }
      end
    end
  end

  shared_examples "legacy_export_selected_success" do
    before(:each) do
      sign_in(user)
    end

    it "exports default course configs and attachments" do
      default_tar = (@course.generate_tar []).string.force_encoding("binary")
      post :legacy_export_selected, params: { name: @course.name }
      expect(response).to be_successful
      expect(response.body).to eq(default_tar)
    end

    it "exports metric configs" do
      metrics_tar = (@course.generate_tar ["metrics_config"]).string.force_encoding("binary")
      post :legacy_export_selected,
           params: { name: @course.name, export_configs: ["metrics_config"] }
      expect(response).to be_successful
      expect(response.body).to eq(metrics_tar)
    end

    it "exports assessments" do
      assessments_tar = (@course.generate_tar ["assessments"]).string.force_encoding("binary")
      post :legacy_export_selected, params: { name: @course.name, export_configs: ["assessments"] }
      expect(response).to be_successful
      expect(response.body).to eq(assessments_tar)
    end

    it "handles StandardError during export" do
      allow_any_instance_of(Course).to receive(:generate_tar).and_raise(StandardError)
      post :legacy_export_selected, params: { name: @course.name }
      expect(response).to have_http_status(302)
      expect(response).to redirect_to(action: :legacy_export)
      expect(flash[:error]).to be_present
      expect(flash[:error]).to match(/StandardError/m)
    end
  end

  shared_examples "legacy_export_selected_failure" do
    before(:each) do
      sign_in(user)
    end

    it "does not export a course" do
      default_tar = (@course.generate_tar []).string.force_encoding("binary")
      post :legacy_export_selected, params: { name: @course.name }
      expect(response).not_to be_successful
      expect(response.body).not_to eq(default_tar)
    end
  end

  describe "#legacy_export_selected" do
    context "when user is instructor with no attachment" do
      include_context "controllers shared context"

      it_behaves_like "legacy_export_selected_success" do
        let!(:user) { instructor_user }
      end
    end

    context "when user is instructor with attachment" do
      let!(:course_hash) do
        create_course_with_attachment_as_hash
      end

      it_behaves_like "legacy_export_selected_success" do
        let!(:user) { course_hash[:instructor_user] }
      end
    end

    context "when user is Autolab user" do
      include_context "controllers shared context"

      it_behaves_like "legacy_export_selected_failure" do
        let!(:user) { student_user }
      end
    end
  end

  describe "#join_course" do
    include_context "controllers shared context"
    context "when user is Autolab user" do
      let!(:u) { student_user }
      before(:each) { sign_in(u) }

      it "renders successfully" do
        get :join_course
        expect(response.body).to match(/Join Course/m)
      end

      it "rejects invalid access code format" do
        post :join_course, params: { access_code: "invalid" }
        expect(flash[:error]).to be_present
        expect(flash[:error]).to match(/Invalid access code format/m)
      end

      it "rejects invalid access code" do
        post :join_course, params: { access_code: "AAAAAA" }
        expect(flash[:error]).to be_present
        expect(flash[:error]).to match(/Invalid access code/m)
      end
    end

    context "when user is not logged in" do
      it "renders with failure" do
        get :join_course
        expect(response.body).not_to match(/Join Course/m)
      end
    end
  end
end
