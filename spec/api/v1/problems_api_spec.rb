require 'rails_helper'
require_relative "api_shared_context"

RSpec.describe Api::V1::ProblemsController, type: :controller do
  describe 'GET #problems' do
    include_context "api shared context"

    it 'fails to find the course' do
      get :index, params: {
        access_token: token.token,
        course_name: 8.times.map { rand(65..90).chr }.join, # random course name
        assessment_name: assessment.name
      }
      expect(response.response_code).to eq(404)
    end

    it 'returns all the problems of an assignment' do
      get :index, params: { access_token: token.token, course_name: course.name,
                            assessment_name: assessment.name }
      expect(response.response_code).to eq(200)
      msg = JSON.parse(response.body)
      expect(msg.length).to eq(assessment.problems.count)
    end
  end
end
