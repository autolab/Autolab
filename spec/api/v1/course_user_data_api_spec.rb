require 'rails_helper'
require_relative "api_shared_context.rb"

# test cases common to all CUD routes
# requires "api shared context" to have been included
RSpec.shared_examples "a CUD route" do |method, action|
  it 'fails to authenticate when the app does not have instructor scope' do
    send method, action, :access_token => token.token, :course_name => course.name, :email => user.email
    expect(response.response_code).to eq(403)
  end

  it 'fails to authenticate when the user is not an instructor' do
    send method, action, :access_token => instructor_token_for_user.token, :course_name => course.name,
      :email => instructor.email
    expect(response.response_code).to eq(403)
  end
end

RSpec.describe Api::V1::CourseUserDataController, :type => :controller do

  describe 'GET index' do
    include_context "api shared context"

    it_behaves_like "a CUD route", :get, :index

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

  describe 'POST create' do
    include_context "api shared context"

    it_behaves_like "a CUD route", :post, :create

    it 'fails to create when user does not exist' do
      rand_user_email = 16.times.map { (65 + rand(26)).chr }.join
      post :create, :access_token => instructor_token_for_instructor.token, 
        :course_name => course.name, :email => rand_user_email, :lecture => "1",
        :section => "A", :auth_level => "student"
      expect(response.response_code).to eq(400)

      user = User.find_by(email: rand_user_email)
      expect(user).to be_nil
    end

    it 'fails to create when user is already in course' do
      rand_user_email = 16.times.map { (65 + rand(26)).chr }.join
      post :create, :access_token => instructor_token_for_instructor.token, 
        :course_name => course.name, :email => user.email, :lecture => "1",
        :section => "A", :auth_level => "student"
      expect(response.response_code).to eq(400)
    end

    context "when user is valid" do
      before(:each) do
        email_name = 16.times.map { (65 + rand(26)).chr }.join
        email_domain = 8.times.map { (65 + rand(26)).chr }.join
        @newUser = User.new(email: email_name + "@" + email_domain + ".com",
          first_name: "hello", last_name: "there", password: "password")
        @newUser.save!
      end

      it 'creates a student CUD' do
        post :create, :access_token => instructor_token_for_instructor.token, 
          :course_name => course.name, :email => @newUser.email, :lecture => "1",
          :section => "A", :auth_level => "student"
        expect(response.response_code).to eq(200)

        cud = @newUser.course_user_data.find_by(course: course)
        expect(cud).not_to be_nil
        expect(cud.user).to eq(@newUser)
        expect(cud.lecture).to eq("1")
        expect(cud.section).to eq("A")
        expect(cud.instructor).to be_falsey
        expect(cud.course_assistant).to be_falsey
        expect(cud.dropped).to be_falsey
      end

      it 'creates a dropped student CUD' do
        post :create, :access_token => instructor_token_for_instructor.token, 
          :course_name => course.name, :email => @newUser.email, :lecture => "1",
          :section => "A", :auth_level => "student", :dropped => true
        expect(response.response_code).to eq(200)

        cud = @newUser.course_user_data.find_by(course: course)
        expect(cud).not_to be_nil
        expect(cud.dropped).to be_truthy
      end

      it 'creates an instructor CUD' do
        post :create, :access_token => instructor_token_for_instructor.token, 
          :course_name => course.name, :email => @newUser.email, :lecture => "2",
          :section => "D", :auth_level => "instructor"
        expect(response.response_code).to eq(200)

        cud = @newUser.course_user_data.find_by(course: course)
        expect(cud).not_to be_nil
        expect(cud.user).to eq(@newUser)
        expect(cud.lecture).to eq("2")
        expect(cud.section).to eq("D")
        expect(cud.instructor).to be_truthy
        expect(cud.course_assistant).to be_falsey
        expect(cud.dropped).to be_falsey
      end

      it 'fails to create if missing parameter' do
        post :create, :access_token => instructor_token_for_instructor.token, 
          :course_name => course.name, :email => @newUser.email, :lecture => "1",
          :auth_level => "student" # no section
        expect(response.response_code).to eq(400)
      end

      it 'fails to create if auth_level is invalid' do
        post :create, :access_token => instructor_token_for_instructor.token, 
          :course_name => course.name, :email => @newUser.email, :lecture => "1",
          :section => "A", :auth_level => "blah"
        expect(response.response_code).to eq(400)
      end
    end
  end

  describe 'PUT update' do
    include_context "api shared context"

    it_behaves_like "a CUD route", :put, :update

    it 'fails to update when user does not exist' do
      rand_user_email = 16.times.map { (65 + rand(26)).chr }.join
      put :update, :access_token => instructor_token_for_instructor.token, 
        :course_name => course.name, :email => rand_user_email, :lecture => "1",
        :section => "A", :auth_level => "student"
      expect(response.response_code).to eq(400)

      no_user = User.find_by(email: rand_user_email)
      expect(no_user).to be_nil
    end

    it 'fails to update when user is not in the course' do
      email_name = 16.times.map { (65 + rand(26)).chr }.join
      email_domain = 8.times.map { (65 + rand(26)).chr }.join
      newUser = User.new(email: email_name + "@" + email_domain + ".com",
        first_name: "hello", last_name: "there", password: "password")
      newUser.save!

      put :update, :access_token => instructor_token_for_instructor.token,
        :course_name => course.name, :email => newUser.email, :lecture => "1",
        :section => "A", :auth_level => "student"
      expect(response.response_code).to eq(404)

      no_cud = newUser.course_user_data.find_by(course: course)
      expect(no_cud).to be_nil
    end

    context 'when user is valid' do
      it 'updates the auth_level correctly' do
        put :update, :access_token => instructor_token_for_instructor.token,
          :course_name => course.name, :email => user.email, :lecture => "1",
          :auth_level => "course_assistant"
        expect(response.response_code).to eq(200)
        msg = JSON.parse(response.body)

        expect(msg['auth_level']).to eq('course_assistant')
        cud = user.course_user_data.find_by(course: course)
        expect(cud.course_assistant).to be_truthy
        expect(cud.instructor).to be_falsey
      end

      it 'updates other info correctly' do
        cud = user.course_user_data.find_by(course: course)
        new_lecture = cud.lecture + "_24"
        new_section = cud.section + "_42"
        new_dropped = !cud.dropped
        put :update, :access_token => instructor_token_for_instructor.token,
          :course_name => course.name, :email => user.email,
          :lecture => new_lecture, :section => new_section, :dropped => new_dropped
        expect(response.response_code).to eq(200)
        msg = JSON.parse(response.body)

        expect(msg['lecture']).to eq(new_lecture)
        expect(msg['section']).to eq(new_section)
        expect(msg['dropped']).to eq(new_dropped)
        cud = user.course_user_data.find_by(course: course)
        expect(cud.lecture).to eq(new_lecture)
        expect(cud.section).to eq(new_section)
        expect(cud.dropped).to eq(new_dropped)
      end
    end
  end

end