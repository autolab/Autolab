require 'rails_helper'
require_relative "tango_mock"
require_relative "api_shared_context"

RSpec.describe "API Submission Autograding Roundtrip Test", type: :request do
  include_context "tango mock"
  include_context "api handin context"

  it "accepts handin and handles Tango callback correctly" do
    # count number of submissions before
    sub_count = Submission.where(course_user_datum_id: @ap_cud.id,
                                 assessment: @adder_asm).count

    # perform submission
    subm = {}
    subm['file'] = @handin_file
    post "/api/v1/courses/#{@ap_course.name}/assessments/#{@adder_asm.name}/submit",
         params: { access_token: token.token, submission: subm }
    msg = JSON.parse(response.body)
    expect(response.response_code).to eq(200)
    expect(msg).to include('version')
    expect(msg['version']).to match(sub_count + 1)

    # count submissions after
    sub_count_after = Submission.where(course_user_datum_id: @ap_cud.id,
                                       assessment: @adder_asm).count
    expect(sub_count_after - 1).to eq(sub_count)

    # check submitted_by_app_id
    latest_sub = Submission.where(course_user_datum_id: @ap_cud.id,
                                  assessment: @adder_asm).order(:version).last
    expect(latest_sub.submitted_by_app_id).to eq(application.id)

    # mock a Tango callback
    mock_tango_callback(@ap_course.name, @adder_asm.name, latest_sub.dave, latest_sub.id,
                        'feedback.txt')

    # check score
    problem = @adder_asm.problems.find_by(name: "autograded")
    score = Score.find_by(submission: latest_sub, problem:)
    expect(score).not_to be_nil
    expect(score.score).to eq(42)
  end
end
