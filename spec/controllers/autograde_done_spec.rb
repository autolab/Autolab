require "rails_helper"
require_relative "controllers_shared_context"

# Regression tests for the unauthenticated Tango callback. A request with a
# missing/blank dave used to match every graded submission (dave IS NULL).
RSpec.describe AssessmentsController, type: :controller do
  include_context "controllers shared context"

  let(:url_params) { { course_name: course.name, name: assessment.name } }
  let(:student_cud) { course.course_user_data.find_by(user_id: student_user.id) }
  let(:payload) { '{"scores":{"A":1000,"B":1000}}' }

  before do
    create(:autograder, assessment:) unless assessment.has_autograder?
    allow_any_instance_of(AssessmentsController).to receive(:extend_config_module)
    allow_any_instance_of(AssessmentsController).to receive(:require_relative)
    allow_any_instance_of(Assessment).to receive(:overwrites_method?).and_return(false)
  end

  def post_callback(params)
    request.headers["Content-Type"] = "text/plain"
    post :autograde_done, params: url_params.merge(params), body: payload
  end

  it "rejects a callback with no dave and grades nothing" do
    expect_any_instance_of(AssessmentsController).not_to receive(:autogradeDone)
    post_callback({})
    expect(response).to have_http_status(:not_found)
  end

  it "rejects a callback with a blank dave" do
    expect_any_instance_of(AssessmentsController).not_to receive(:autogradeDone)
    post_callback(dave: "")
    expect(response).to have_http_status(:not_found)
  end

  it "rejects an unknown dave" do
    expect_any_instance_of(AssessmentsController).not_to receive(:autogradeDone)
    post_callback(dave: "a" * 64)
    expect(response).to have_http_status(:not_found)
  end

  it "rejects callers outside TANGO_CALLBACK_ALLOWED_IPS" do
    submission = create(:submission, assessment:, course_user_datum: student_cud,
                                     dave: "b" * 64)
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with("TANGO_CALLBACK_ALLOWED_IPS").and_return("10.99.0.0/16")
    expect_any_instance_of(AssessmentsController).not_to receive(:autogradeDone)
    post_callback(dave: submission.dave, submission_id: submission.id)
    expect(response).to have_http_status(:not_found)
  end

  it "grades the submission matching a valid dave (Tango multipart callback)" do
    submission = create(:submission, assessment:, course_user_datum: student_cud,
                                     dave: SecureRandom.hex(32))
    expect_any_instance_of(AssessmentsController).to receive(:autogradeDone) do |_ctrl, subs, fb|
      expect(subs.map(&:id)).to eq([submission.id])
      expect(fb).to include("Autograder")
    end
    feedback = StringIO.new("Autograder output\n{\"scores\":{}}")
    file = Rack::Test::UploadedFile.new(feedback, "text/plain", original_filename: "file")
    callback_params = { dave: submission.dave, submission_id: submission.id, file: }
    post :autograde_done, params: url_params.merge(callback_params)
    expect(response).to have_http_status(:no_content)
  end
end
