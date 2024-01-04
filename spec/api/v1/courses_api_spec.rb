require 'rails_helper'
require_relative "api_shared_context"

RSpec.describe Api::V1::CoursesController, type: :controller do
  describe 'GET #index' do
    include_context "api shared context"

    it 'fails to authenticate when the token is invalid' do
      get :index, params: { access_token: token.token.length.times.map {
                                            rand(65..90).chr
                                          }.join } # a random token
      expect(response.response_code).to eq(401)
    end

    it 'fails scope test' do
      get :index, params: { access_token: user_info_token.token }
      expect(response.response_code).to eq(403)
    end

    it 'returns all the user\'s courses' do
      get :index, params: { access_token: token.token }
      expect(response.response_code).to eq(200)
      expect{ JSON.parse(response.body) }.not_to raise_exception
    end

    it 'returns only current courses' do
      get :index, params: { access_token: token.token, state: "current" }
      expect(response.response_code).to eq(200)
      msg = JSON.parse(response.body)
      msg.each do |c|
        course = Course.find_by(name: c["name"])
        expect(course.temporal_status).to eq(:current)
      end
    end

    it 'reports a state error' do
      get :index, params: { access_token: token.token, state: "blah" }
      expect(response.response_code).to eq(400)
      msg = JSON.parse(response.body)
      expect(msg["error"]).to eq("Unexpected course state")
    end
  end

  describe 'GET create' do
    include_context "api shared context"

    before(:each) do
      @course_name = "15213-f15"
      @course_sem = "f15"
      @instructor_email = admin_user.email
    end

    it 'fails to authenticate when the app does not have admin scope' do
      get :create, params: { access_token: token.token }
      expect(response.response_code).to eq(403)
    end

    it 'fails to authenticate when the user is not an admin' do
      get :create, params: { access_token: admin_token_for_user.token }
      expect(response.response_code).to eq(403)
    end

    it 'fails to create when name is invalid' do
      get :create,
          params: { access_token: admin_token_for_admin.token,
                    name: "Hello There",
                    semester: @course_sem,
                    instructor_email: @instructor_email }
      expect(response.response_code).not_to eq(200)
    end

    it 'creates a course successfully for an existing user' do
      get :create,
          params: { access_token: admin_token_for_admin.token,
                    name: @course_name, semester: @course_sem,
                    instructor_email: @instructor_email }
      expect(response.response_code).to eq(200)

      course = Course.find_by(name: @course_name)
      expect(course).not_to be_nil
      expect(course.semester).to eq(@course_sem)

      cud = admin_user.course_user_data.find_by(course:)
      expect(cud).not_to be_nil
      expect(cud.instructor).to be_truthy
    end

    it 'creates a course successfully for a non-existing user' do
      new_email = "new_instructor@test.com"
      get :create,
          params: { access_token: admin_token_for_admin.token,
                    name: @course_name, semester: @course_sem,
                    instructor_email: new_email }
      expect(response.response_code).to eq(200)

      newly_created_user = User.find_by(email: new_email)
      expect(newly_created_user).not_to be_nil

      course = Course.find_by(name: @course_name)
      expect(course).not_to be_nil
      expect(course.semester).to eq(@course_sem)

      cud = newly_created_user.course_user_data.find_by(course:)
      expect(cud).not_to be_nil
      expect(cud.instructor).to be_truthy
    end
  end
end
