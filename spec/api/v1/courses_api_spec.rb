require 'rails_helper'

RSpec.describe Api::V1::CoursesController, :type => :controller do
	describe 'GET #index' do
    user = get_user
    let!(:application) { Doorkeeper::Application.create! :name => "TestApp", :redirect_uri => "https://example.com", :scopes => "user_info user_courses" }
    let!(:token) { Doorkeeper::AccessToken.create! :application_id => application.id, :resource_owner_id => user.id, :scopes => "user_info user_courses" }

    # an application with insufficient scope
    let!(:bad_application) { Doorkeeper::Application.create! :name => "BadApp", :redirect_uri => "https://bad-example.com", :scopes => "user_info" }
    let!(:bad_token) { Doorkeeper::AccessToken.create! :application_id => bad_application.id, :resource_owner_id => user.id, :scopes => "user_info" }

    it 'fails to authenticate' do
      get :index, :access_token => token.token.length.times.map { (65 + rand(26)).chr }.join # a random token
      expect(response.response_code).to eq(401)
    end

    it 'fails scope test' do
      get :index, :access_token => bad_token.token
      expect(response.response_code).to eq(403)
    end

    it 'returns all the user\'s courses' do
      get :index, :access_token => token.token
      expect(response.response_code).to eq(200)
      expect{ msg = JSON.parse(response.body) }.not_to raise_exception
    end

    it 'returns only current courses' do
      get :index, :access_token => token.token, :state => "current"
      expect(response.response_code).to eq(200)
      msg = JSON.parse(response.body)
      msg.each do |c|
        course = Course.find(:name => c["name"])
        expect{course.temporal_status}.to eq(:current)
      end
    end

    it 'reports a state error' do
      get :index, :access_token => token.token, :state => "blah"
      expect(response.response_code).to eq(400)
      msg = JSON.parse(response.body)
      expect(msg["error"]).to eq("Unexpected course state")
    end
  end
end