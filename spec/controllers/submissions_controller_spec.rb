require "rails_helper"
include ControllerMacros
require_relative "controllers_shared_context"

RSpec.describe SubmissionsController, type: :controller do
  render_views

  shared_examples "index_success" do
    it "renders successfully" do
      sign_in(user)
      get :index, params: { course_name: @course.name, assessment_name: @assessment.name }
      expect(response).to be_successful
      expect(response.body).to match(/Manage Submissions/m)
    end
  end

  shared_examples "index_failure" do
    it "renders with failure" do
      sign_in(user)
      get :index, params: { course_name: @course.name, assessment_name: @assessment.name }
      expect(response).not_to be_successful
      expect(response.body).not_to match(/Manage Submissions/m)
    end
  end

  shared_examples "new_success" do
    it "renders successfully" do
      sign_in(user)
      get(:new, params:)
      expect(response).to be_successful
      expect(response.body).to match(/Create Submission/m)
    end
  end

  shared_examples "new_failure" do
    it "renders with failure" do
      sign_in(user)
      get(:new, params:)
      expect(response).not_to be_successful
      expect(response.body).not_to match(/Create Submission/m)
    end
  end

  shared_examples "new_error" do
    it "errors on bad cud params" do
      sign_in(user)
      get(:new, params:)
      expect(flash[:error]).to be_present
      expect(response.body).not_to match(/Create Submission/m)
    end
  end

  shared_examples "create_success" do
    it "creates nil assessment correctly" do
      sign_in(user)
      student_cud = CourseUserDatum.find_by(user_id: student_user.id, course_id: @course.id)
      # these stubs are necessary for the submission to go through
      allow_any_instance_of(Submission).to receive(:course_user_datum).and_return(student_cud)
      allow_any_instance_of(Submission).to receive(:aud).and_return(
        AssessmentUserDatum.find_by(assessment_id: @assessment.id,
                                    course_user_datum_id: student_cud.id)
      )
      allow_any_instance_of(ActiveRecord::Associations::CollectionProxy)
        .to receive(:find).and_return(nil)
      post(:create, params: { course_name: @course.name, assessment_name: @assessment.name,
                              submission: { course_user_datum_id: student_user.id.to_s,
                                            tweak_attributes: { kind: "points" },
                                            notes: "" } })
      expect(flash[:success]).to be_present
      expect(flash[:success]).to match(/Submission Created/m)
    end
    it "creates assessment with file correctly" do
      sign_in(user)
      student_cud = CourseUserDatum.find_by(user_id: student_user.id, course_id: @course.id)
      allow_any_instance_of(Submission).to receive(:course_user_datum).and_return(student_cud)
      allow_any_instance_of(Submission).to receive(:aud).and_return(
        AssessmentUserDatum.find_by(assessment_id: @assessment.id,
                                    course_user_datum_id: student_cud.id)
      )
      allow_any_instance_of(ActiveRecord::Associations::CollectionProxy)
        .to receive(:find).and_return(nil)
      post(:create, params: { course_name: @course.name, assessment_name: @assessment.name,
                              submission: { course_user_datum_id: student_user.id.to_s,
                                            tweak_attributes: { kind: "points" },
                                            file: fixture_file_upload("attachments/course.txt",
                                                                      "text/plain"),
                                            notes: "" } })
      expect(flash[:success]).to be_present
      expect(flash[:success]).to match(/Submission Created/m)
    end
  end

  shared_examples "edit_success" do
    it "renders successfully" do
      sign_in(user)
      get :edit, params: { course_name: @course.name, assessment_name: @assessment.name,
                           id: @submissions.id }
      expect(response).to be_successful
      expect(response.body).to match(/Edit/m)
    end
  end

  shared_examples "edit_failure" do
    it "renders with failure" do
      sign_in(user)
      get :edit, params: { course_name: @course.name, assessment_name: @assessment.name,
                           id: @submissions.id }
      expect(response).not_to be_successful
      expect(response.body).not_to match(/Edit/m)
    end
  end

  shared_examples "destroyConfirm_failure" do
    it "renders with failure" do
      sign_in(user)
      get :destroyConfirm, params: { course_name: @course.name, assessment_name: @assessment.name,
                                     id: get_first_submission_by_assessment(@assessment).id }
      expect(response).not_to be_successful
      expect(response.body).not_to match(/Deleting a student's submission/m)
    end
  end

  shared_examples "destroyConfirm_success" do
    it "renders with success" do
      sign_in(user)
      get :destroyConfirm, params: { course_name: @course.name, assessment_name: @assessment.name,
                                     id: get_first_submission_by_assessment(@assessment).id }
      expect(response).to be_successful
      expect(response.body).to match(/Deleting a student's submission/m)
    end
  end

  shared_examples "destroy_success" do
    it "destroys a student's submission" do
      sign_in(user)
      submission = get_first_submission_by_assessment(@assessment)
      expect do
        post :destroy, params: { course_name: @course.name, assessment_name: @assessment.name,
                                 id: submission.id }
      end.to change(Submission, :count).by(-1)
      expect(response).to have_http_status(302)
      expect(flash[:success])
    end
  end

  shared_examples "destroy_failure" do
    it "fails to destroy submission" do
      sign_in(user)
      submission = Submission.where(course_user_datum_id: get_first_cud_by_uid(user.id)).first
      expect do
        post :destroy, params: { course_name: @course.name, assessment_name: @assessment.name,
                                 id: submission.id }
      end.to change(Submission, :count).by(0)
      expect(response).to have_http_status(302)
      expect(flash[:error])
    end
  end

  describe "#index" do
    include_context "controllers shared context"
    context "when user is Autolab admin" do
      let!(:user) { admin_user }
      it_behaves_like "index_success"
    end

    context "when user is Instructor" do
      let!(:user) { instructor_user }
      it_behaves_like "index_success"
    end

    context "when user is student" do
      let!(:user) { student_user }
      it_behaves_like "index_failure"
    end

    context "when user is Course Assistant" do
      let!(:user) { course_assistant_user }
      it_behaves_like "index_failure"
    end
  end

  describe "#new" do
    include_context "controllers shared context"
    context "when user is Autolab admin" do
      let!(:user) { admin_user }
      it_behaves_like "new_success" do
        let!(:params) { { course_name: @course.name, assessment_name: @assessment.name } }
      end
    end

    context "when user is Instructor" do
      let!(:user) { instructor_user }
      it_behaves_like "new_success" do
        let!(:params) { { course_name: @course.name, assessment_name: @assessment.name } }
      end
      it_behaves_like "new_success" do
        # should be able to provide a CUD and it be accepted
        let!(:params) {
          { course_name: @course.name, assessment_name: @assessment.name,
            course_user_datum_id: CourseUserDatum.find_by(user_id: student_user.id,
                                                          course_id: @course.id).id.to_s }
        }
      end
      it_behaves_like "new_error" do
        # should be able to provide a bad CUD and it be a rejected
        let!(:params) {
          { course_name: @course.name, assessment_name: @assessment.name,
            course_user_datum_id: 12_345_678 }
        }
      end
    end

    context "when user is student" do
      let!(:user) { student_user }
      it_behaves_like "new_failure" do
        let!(:params) { { course_name: @course.name, assessment_name: @assessment.name } }
      end
    end

    context "when user is Course Assistant" do
      let!(:user) { course_assistant_user }
      it_behaves_like "new_failure" do
        let!(:params) { { course_name: @course.name, assessment_name: @assessment.name } }
      end
    end
  end

  describe "#create" do
    include_context "controllers shared context"
    context "when user is Instructor" do
      let!(:user) { instructor_user }
      it_behaves_like "create_success"
    end
  end

  describe "#edit" do
    include_context "controllers shared context"
    context "when user is Autolab admin" do
      let!(:user) { admin_user }
      it_behaves_like "edit_success"
    end

    context "when user is Instructor" do
      let!(:user) { instructor_user }
      it_behaves_like "edit_success"
    end

    context "when user is student" do
      let!(:user) { student_user }
      it_behaves_like "edit_failure"
    end

    context "when user is Course Assistant" do
      let!(:user) { course_assistant_user }
      it_behaves_like "edit_failure"
    end
  end

  describe "#downloadAll" do
    include_context "controllers shared context"
    context "when user is Instructor of class with submissions" do
      let!(:user) { instructor_user }
      it "downloads all submissions for an assessment" do
        sign_in(user)
        get :downloadAll, params: { course_name: @course.name, assessment_name: @assessment.name }
        expect(response).to be_successful
        Zip::File.open_buffer(response.parsed_body) do |zip_file|
          zip_file.each do |entry|
            if entry.file?
              content = entry.get_input_stream.read
              expect(content).to match(/Hello Dave/m)
            end
          end
        end
      end
    end
  end

  describe "#download" do
    include_context "controllers shared context"
    context "when user is Instructor of class with submissions" do
      let!(:user) { instructor_user }
      it "downloads a student's submission" do
        sign_in(user)
        get :download, params: { course_name: @course.name, assessment_name: @assessment.name,
                                 id: get_first_submission_by_assessment(@assessment).id }
        expect(response).to be_successful
        file_data = response.parsed_body
        expect(file_data).to match(/Hello Dave/m)
      end
    end
    context "when user is student and downloads own submission" do
      let!(:user) { student_user }
      it "downloads submission" do
        sign_in(user)
        submission = Submission.where(course_user_datum_id: get_first_cud_by_uid(user.id)).first
        get :download, params: { course_name: @course.name, assessment_name: @assessment.name,
                                 id: submission.id }
        expect(response).to be_successful
        file_data = response.parsed_body
        expect(file_data).to match(/Hello Dave/m)
      end
    end
  end

  describe "#missing" do
    include_context "controllers shared context"
    context "when user is student" do
      let!(:user) { student_user }
      it "fails to get missing submissions" do
        sign_in(user)
        get :missing, params: { course_name: @course.name, assessment_name: @assessment.name }
        expect(response).not_to be_successful
        expect(response.body).not_to match(/Missing Submissions/m)
      end
    end
    context "when user is Instructor of class with submissions" do
      let!(:user) { instructor_user }
      it "doesn't show missing submissions" do
        sign_in(user)
        get :missing, params: { course_name: @course.name, assessment_name: @assessment.name }
        expect(response).to be_successful
        expect(response.body).to match(/Missing Submissions/m)
        expect(response.body).to match(/No Missing Submissions!/m)
        @students.each do |student|
          expect(response.body).not_to match(/#{student.email}/m)
        end
      end
    end
    context "when user is Instructor of asmt no submissions" do
      let!(:hash) { create_course_no_submissions_hash }
      let!(:user) { instructor_user }
      it "shows missing submissions" do
        sign_in(user)
        get :missing, params: { course_name: @course.name, assessment_name: @assessment.name }
        expect(response).to be_successful
        expect(response.body).to match(/Missing Submissions/m)
        expect(response.body).not_to match(/No Missing Submissions!/m)
        @students.each do |student|
          expect(response.body).to match(/#{student.email}/m)
        end
      end
    end
  end

  describe "#destroyConfirm" do
    include_context "controllers shared context"
    context "when user is Autolab admin" do
      let!(:user) { admin_user }
      it_behaves_like "destroyConfirm_success"
    end

    context "when user is Instructor" do
      let!(:user) { instructor_user }
      it_behaves_like "destroyConfirm_success"
    end

    context "when user is student" do
      let!(:user) { student_user }
      it_behaves_like "destroyConfirm_failure"
    end

    context "when user is Course Assistant" do
      let!(:user) { course_assistant_user }
      it_behaves_like "destroyConfirm_failure"
    end
  end

  describe "#destroy" do
    include_context "controllers shared context"
    context "when user is Autolab admin" do
      let!(:user) { admin_user }
      it_behaves_like "destroy_success"
    end
    context "when user is Instructor" do
      let!(:user) { instructor_user }
      it_behaves_like "destroy_success"
    end
    context "when user is student" do
      let!(:user) { student_user }
      it_behaves_like "destroy_failure"
    end
    context "when user is Course Assistant" do
      let!(:user) { course_assistant_user }
      it "fails to destroy submission" do
        sign_in(user)
        submission = get_first_submission_by_assessment(@assessment)
        expect do
          post :destroy, params: { course_name: @course.name, assessment_name: @assessment.name,
                                   id: submission.id }
        end.to change(Submission, :count).by(0)
        expect(response).to have_http_status(302)
        expect(flash[:error])
      end
    end
  end
end
