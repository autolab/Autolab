require 'rails_helper'

RSpec.describe "API Submission Autograding Roundtrip Test", :type => :request do
  # Note: this test context does not use shared context
  before :each do
    # The adder.py file to hand in
    @handin_file = fixture_file_upload('handins/adder.py', 'text/plain')
    # The AutoPopulate Course
    @ap_course = Course.find_by(:name => 'AutoPopulated')
    @ap_cud = CourseUserDatum.where(:course => @ap_course, :instructor => false, :course_assistant => false).first
    @ap_student = @ap_cud.user
    # The adder.py Assessment
    @adder_asm = Assessment.find_by(:course => @ap_course, :name => 'labtemplate')
    # make sure we can submit to this assessment
    @adder_asm.due_at = Time.now + 1.hour
    @adder_asm.end_at = Time.now + 1.hour
    @adder_asm.save!
  end
  
  let!(:application) { Doorkeeper::Application.create! :name => "TestApp", :redirect_uri => "https://example.com", :scopes => "user_info user_submit" }
  let!(:token) { Doorkeeper::AccessToken.create! :application_id => application.id, :resource_owner_id => @ap_student.id, :scopes => "user_info user_submit" }

  it "accepts handin and handles Tango callback correctly" do
    # count number of submissions before
    sub_count = Submission.where(:course_user_datum_id => @ap_cud.id, :assessment => @adder_asm).count

    # perform submission
    subm = Hash.new
    subm['file'] = @handin_file
    post "/api/v1/courses/#{@ap_course.name}/assessments/#{@adder_asm.name}/submit", :access_token => token.token, :submission => subm
    msg = JSON.parse(response.body)
    expect(response.response_code).to eq(200)
    expect(msg).to include('success')
    expect(msg['success']).to match(/Submitted file [^\s]+ for autograding/)

    # count submissions after
    sub_count_after = Submission.where(:course_user_datum_id => @ap_cud.id, :assessment => @adder_asm).count
    expect(sub_count_after - 1).to eq(sub_count)

    # check submitted_by_app_id
    latest_sub = Submission.where(:course_user_datum_id => @ap_cud.id, :assessment => @adder_asm).order(:version).last
    expect(latest_sub.submitted_by_app_id).to eq(application.id)

    # mock a Tango callback
    feedback_file = fixture_file_upload('feedback.txt', 'text/plain')
    post "/courses/#{@ap_course.name}/assessments/#{@adder_asm.name}/autograde_done?dave=#{latest_sub.dave}&submission_id=#{latest_sub.id}", :file => feedback_file

    # check score
    problem = @adder_asm.problems.find_by(:name => "autograded")
    score = Score.find_by(:submission => latest_sub, :problem => problem)
    expect(score).not_to be_nil
    expect(score.score).to eq(42)
  end
end