require 'rails_helper'

RSpec.describe Api::V1::AssessmentsController, :type => :controller do
  describe 'GET #index' do
    user = get_user
    course = Course.find(get_course_id_by_uid(user.id))
    let!(:application) { Doorkeeper::Application.create! :name => "TestApp", :redirect_uri => "https://example.com", :scopes => "user_info user_courses" }
    let!(:token) { Doorkeeper::AccessToken.create! :application_id => application.id, :resource_owner_id => user.id, :scopes => "user_info user_courses" }

    # an application with insufficient scope
    let!(:bad_application) { Doorkeeper::Application.create! :name => "BadApp", :redirect_uri => "https://bad-example.com", :scopes => "user_info" }
    let!(:bad_token) { Doorkeeper::AccessToken.create! :application_id => bad_application.id, :resource_owner_id => user.id, :scopes => "user_info" }

    it 'fails scope test' do
      get :index, :access_token => bad_token.token, :course_name => course.name
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
    user = get_user
    course = Course.find(get_course_id_by_uid(user.id))
    assessment = course.assessments.offset(rand(course.assessments.count)).first
    let!(:application) { Doorkeeper::Application.create! :name => "TestApp", :redirect_uri => "https://example.com", :scopes => "user_info user_courses" }
    let!(:token) { Doorkeeper::AccessToken.create! :application_id => application.id, :resource_owner_id => user.id, :scopes => "user_info user_courses" }

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
end