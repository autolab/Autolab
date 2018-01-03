require 'rails_helper'
require_relative "api_shared_context.rb"

RSpec.describe Api::V1::AssessmentsController, :type => :controller do
  describe 'GET #index' do
    include_context "api shared context"

    it 'fails scope test' do
      get :index, :access_token => user_info_token.token, :course_name => course.name
      expect(response.response_code).to eq(403)
    end

    it 'fails to find the course' do
      get :index, :access_token => token.token, :course_name => 8.times.map { (65 + rand(26)).chr }.join # random course name
      expect(response.response_code).to eq(404)
    end

    it 'returns all the assessments of a course' do
      get :index, :access_token => token.token, :course_name => course.name
      expect(response.response_code).to eq(200)
      msg = JSON.parse(response.body)
      expect(msg.length).to eq(course.assessments.count)
    end
  end

  describe 'GET #problems' do
    include_context "api shared context"

    it 'fails to find the course' do
      get :index, :access_token => token.token, :course_name => 8.times.map { (65 + rand(26)).chr }.join # random course name
      expect(response.response_code).to eq(404)
    end

    it 'returns all the problems of an assignment' do
      get :problems, :access_token => token.token, :course_name => course.name, :assessment_name => assessment.name
      expect(response.response_code).to eq(200)
      msg = JSON.parse(response.body)
      expect(msg.length).to eq(assessment.problems.count)
    end
  end

  describe 'POST #submit' do
    # Note: this test context does not use shared context
    before :context do
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
      @adder_asm.grading_deadline = Time.now + 1.hour
      @adder_asm.save!
    end

    let!(:bad_application) { Doorkeeper::Application.create! :name => "TestApp", :redirect_uri => "https://example.com", :scopes => "user_info user_courses" }
    let!(:bad_token) { Doorkeeper::AccessToken.create! :application_id => application.id, :resource_owner_id => @ap_student.id, :scopes => "user_info user_courses" }

    let!(:application) { Doorkeeper::Application.create! :name => "TestApp", :redirect_uri => "https://example.com", :scopes => "user_info user_submit" }
    let!(:token) { Doorkeeper::AccessToken.create! :application_id => application.id, :resource_owner_id => @ap_student.id, :scopes => "user_info user_submit" }

    it 'fails scope test' do
      subm = Hash.new
      subm['file'] = @handin_file
      post :submit, :access_token => bad_token.token, :course_name => @ap_course.name, :assessment_name => @adder_asm.name, :submission => subm
      expect(response.response_code).to eq(403)
      msg = JSON.parse(response.body)
      expect(msg).to include('error')
      expect(msg['error']).to include('scope')
    end

    it 'rejects invalid handin with no submission[file] param' do
      subm = Hash.new
      post :submit, :access_token => token.token, :course_name => @ap_course.name, :assessment_name => @adder_asm.name, :submission => subm
      expect(response.response_code).to eq(400)
      msg = JSON.parse(response.body)
      expect(msg).to include('error')
      expect(msg['error']).to include('parameter')
    end

    it 'accepts the handin' do
      # count number of submissions before
      sub_count = Submission.where(:course_user_datum_id => @ap_cud.id, :assessment => @adder_asm).count

      # perform submission
      subm = Hash.new
      subm['file'] = @handin_file
      post :submit, :access_token => token.token, :course_name => @ap_course.name, :assessment_name => @adder_asm.name, :submission => subm
      msg = JSON.parse(response.body)
      expect(response.response_code).to eq(200)
      expect(msg).to include('success')
      expect(msg['success']).to match(/Submitted file [^\s]+ for autograding/)

      # count submissions after
      sub_count_after = Submission.where(:course_user_datum_id => @ap_cud.id, :assessment => @adder_asm).count
      expect(sub_count_after - 1).to eq(sub_count)
    end
  end
end