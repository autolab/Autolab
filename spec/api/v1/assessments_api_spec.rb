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
end