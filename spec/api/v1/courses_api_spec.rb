require 'rails_helper'

RSpec.describe Api::V1::CoursesController, :type => :controller do
	describe 'GET #index' do
    user = get_user
    let!(:application) { Doorkeeper::Application.create! :name => "TestApp", :redirect_uri => "https://example.com" }
    let!(:token) { Doorkeeper::AccessToken.create! :application_id => application.id, :resource_owner_id => user.id }

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
  end
end