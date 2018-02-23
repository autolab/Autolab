require 'rails_helper'
require_relative "api_shared_context.rb"

RSpec.describe Api::V1::CourseUserDataController, :type => :controller do

  describe 'GET index' do
    include_context "api shared context"

    it 'fails to authenticate when the app does not have instructor scope' do
      get :index, :access_token => token.token, :course_name => course.name
      expect(response.response_code).to eq(403)
    end

    it 'fails to authenticate when the user is not an instructor' do
      get :index, :access_token => instructor_token_for_user.token, :course_name => course.name
      expect(response.response_code).to eq(403)
    end

    it 'returns the correct number of users and have the correct fields' do
      get :index, :access_token => instructor_token_for_instructor.token, :course_name => course.name
      expect(response.response_code).to eq(200)
      msg = JSON.parse(response.body)

      user_count = course.course_user_data.joins(:user).count
      expect(msg.length).to eq(user_count)

      rand_user_data = msg[rand(user_count)]
      expect(rand_user_data).to include('email')

      rand_user = User.find_by(email: rand_user_data['email'])
      expect(rand_user).not_to be_nil
      rand_user_cud = rand_user.course_user_data.find_by(course: course)
      expect(rand_user_cud).not_to be_nil

      expect(rand_user_data['first_name']).to eq(rand_user.first_name)
      expect(rand_user_data['last_name']).to eq(rand_user.last_name)
      expect(rand_user_data['lecture']).to eq(rand_user_cud.lecture)
      expect(rand_user_data['section']).to eq(rand_user_cud.section)
      expect(rand_user_data['nickname']).to eq(rand_user_cud.nickname)
      expect(rand_user_data['dropped']).to eq(rand_user_cud.dropped)
    end

  end

end