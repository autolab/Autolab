require 'rails_helper'

RSpec.describe Api::V1::AssessmentsController, :type => :controller do
  describe 'GET #index' do
    user = get_user
    course = Course.find(get_course_id_by_uid(user.id))
    let!(:application) { Doorkeeper::Application.create! :name => "TestApp", :redirect_uri => "https://example.com" }
    let!(:token) { Doorkeeper::AccessToken.create! :application_id => application.id, :resource_owner_id => user.id }

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
    let!(:application) { Doorkeeper::Application.create! :name => "TestApp", :redirect_uri => "https://example.com" }
    let!(:token) { Doorkeeper::AccessToken.create! :application_id => application.id, :resource_owner_id => user.id }

    it 'returns all the problems of an assignment' do
      get :problems, :access_token => token.token, :course_name => course.name, :assessment_name => assessment.name
      expect(response.response_code).to eq(200)
      msg = JSON.parse(response.body)
      expect(msg.length).to eq(assessment.problems.count)
    end
  end
end