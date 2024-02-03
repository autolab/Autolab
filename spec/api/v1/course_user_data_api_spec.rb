require 'rails_helper'
require_relative "api_shared_context"

# test cases common to all CUD routes
# requires "api shared context" to have been included
RSpec.shared_examples "a CUD route" do |method, action|
  it 'fails to authenticate when the app does not have instructor scope' do
    send method, action,
         params: { access_token: token.token, course_name: course.name, email: user.email }
    expect(response.response_code).to eq(403)
  end

  it 'fails to authenticate when the user is not an instructor' do
    send method, action, params: { access_token: instructor_token_for_user.token,
                                   course_name: course.name,
                                   email: instructor.email }
    expect(response.response_code).to eq(403)
  end
end

# test cases common to all CUD member routes
# requires "api shared context" to have been included
RSpec.shared_examples "a CUD member route" do |method, action|
  it "fails to #{action} when user does not exist" do
    rand_user_email = 16.times.map { rand(65..90).chr }.join
    send method, action, params: { access_token: instructor_token_for_instructor.token,
                                   course_name: course.name, email: rand_user_email, lecture: "1",
                                   section: "A", auth_level: "student" }
    expect(response.response_code).to eq(400)

    no_user = User.find_by(email: rand_user_email)
    expect(no_user).to be_nil
  end

  it "fails to #{action} when user is not in the course" do
    email_name = 16.times.map { rand(65..90).chr }.join
    email_domain = 8.times.map { rand(65..90).chr }.join
    newUser = User.new(email: "#{email_name}@#{email_domain}.com",
                       first_name: "hello", last_name: "there", password: "password")
    newUser.save!

    send method, action, params: { access_token: instructor_token_for_instructor.token,
                                   course_name: course.name, email: newUser.email, lecture: "1",
                                   section: "A", auth_level: "student" }
    expect(response.response_code).to eq(404)

    no_cud = newUser.course_user_data.find_by(course:)
    expect(no_cud).to be_nil
  end
end

RSpec.describe Api::V1::CourseUserDataController, type: :controller do
  describe 'GET index' do
    include_context "api shared context"

    it_behaves_like "a CUD route", :get, :index

    it 'returns the correct number of users and have the correct fields' do
      get :index,
          params: { access_token: instructor_token_for_instructor.token,
                    course_name: course.name }
      expect(response.response_code).to eq(200)
      msg = JSON.parse(response.body)

      user_count = course.course_user_data.joins(:user).count
      expect(msg.length).to eq(user_count)

      rand_user_data = msg[rand(user_count)]
      expect(rand_user_data).to include('email')

      rand_user = User.find_by(email: rand_user_data['email'])
      expect(rand_user).not_to be_nil
      rand_user_cud = rand_user.course_user_data.find_by(course:)
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
      rand_user_email = 16.times.map { rand(65..90).chr }.join
      post :create, params: { access_token: instructor_token_for_instructor.token,
                              course_name: course.name, email: rand_user_email, lecture: "1",
                              section: "A", auth_level: "student" }
      expect(response.response_code).to eq(400)

      user = User.find_by(email: rand_user_email)
      expect(user).to be_nil
    end

    it 'fails to create when user is already in course' do
      post :create, params: { access_token: instructor_token_for_instructor.token,
                              course_name: course.name, email: user.email, lecture: "1",
                              section: "A", auth_level: "student" }
      expect(response.response_code).to eq(400)
    end

    context "when user is valid" do
      before(:each) do
        email_name = 16.times.map { rand(65..90).chr }.join
        email_domain = 8.times.map { rand(65..90).chr }.join
        @newUser = User.new(email: "#{email_name}@#{email_domain}.com",
                            first_name: "hello", last_name: "there", password: "password")
        @newUser.save!
      end

      it 'creates a student CUD' do
        post :create, params: { access_token: instructor_token_for_instructor.token,
                                course_name: course.name, email: @newUser.email, lecture: "1",
                                section: "A", auth_level: "student", grade_policy: "letter" }
        expect(response.response_code).to eq(200)

        cud = @newUser.course_user_data.find_by(course:)
        expect(cud).not_to be_nil
        expect(cud.user).to eq(@newUser)
        expect(cud.lecture).to eq("1")
        expect(cud.section).to eq("A")
        expect(cud.grade_policy).to eq("letter")
        expect(cud.instructor).to be_falsey
        expect(cud.course_assistant).to be_falsey
        expect(cud.dropped).to be_falsey
      end

      it 'creates a dropped student CUD' do
        post :create, params: { access_token: instructor_token_for_instructor.token,
                                course_name: course.name, email: @newUser.email, lecture: "1",
                                section: "A", auth_level: "student", dropped: true }
        expect(response.response_code).to eq(200)

        cud = @newUser.course_user_data.find_by(course:)
        expect(cud).not_to be_nil
        expect(cud.dropped).to be_truthy
      end

      it 'creates an instructor CUD' do
        post :create, params: { access_token: instructor_token_for_instructor.token,
                                course_name: course.name, email: @newUser.email, lecture: "2",
                                section: "D", auth_level: "instructor" }
        expect(response.response_code).to eq(200)

        cud = @newUser.course_user_data.find_by(course:)
        expect(cud).not_to be_nil
        expect(cud.user).to eq(@newUser)
        expect(cud.lecture).to eq("2")
        expect(cud.section).to eq("D")
        expect(cud.instructor).to be_truthy
        expect(cud.course_assistant).to be_falsey
        expect(cud.dropped).to be_falsey
      end

      it 'fails to create if missing parameter' do
        post :create, params: { access_token: instructor_token_for_instructor.token,
                                course_name: course.name, email: @newUser.email, lecture: "1",
                                auth_level: "student" } # no section
        expect(response.response_code).to eq(400)
      end

      it 'fails to create if auth_level is invalid' do
        post :create, params: { access_token: instructor_token_for_instructor.token,
                                course_name: course.name, email: @newUser.email, lecture: "1",
                                section: "A", auth_level: "blah" }
        expect(response.response_code).to eq(400)
      end
    end
  end

  describe 'GET show' do
    include_context "api shared context"

    it_behaves_like "a CUD route", :get, :show

    it_behaves_like "a CUD member route", :get, :show

    context 'when user is valid' do
      it 'returns the info correctly' do
        get :show, params: { access_token: instructor_token_for_instructor.token,
                             course_name: course.name, email: user.email }
        expect(response.response_code).to eq(200)
        msg = JSON.parse(response.body)

        cud = user.course_user_data.find_by(course:)
        expect(msg['nickname']).to eq(cud.nickname)
        expect(msg['dropped']).to eq(cud.dropped)
        expect(msg['lecture']).to eq(cud.lecture)
        expect(msg['first_name']).to eq(user.first_name)
        expect(msg['last_name']).to eq(user.last_name)
      end
    end
  end

  describe 'PUT update' do
    include_context "api shared context"

    it_behaves_like "a CUD route", :put, :update

    it_behaves_like "a CUD member route", :put, :update

    context 'when user is valid' do
      it 'updates the auth_level correctly' do
        put :update, params: { access_token: instructor_token_for_instructor.token,
                               course_name: course.name, email: user.email, lecture: "1",
                               auth_level: "course_assistant" }
        expect(response.response_code).to eq(200)
        msg = JSON.parse(response.body)

        expect(msg['auth_level']).to eq('course_assistant')
        cud = user.course_user_data.find_by(course:)
        expect(cud.course_assistant).to be_truthy
        expect(cud.instructor).to be_falsey
      end

      it 'updates other info correctly' do
        cud = user.course_user_data.find_by(course:)
        new_lecture = "#{cud.lecture}_24"
        new_section = "#{cud.section}_42"
        new_dropped = !cud.dropped
        new_grade_policy = "pass_fail"
        put :update, params: { access_token: instructor_token_for_instructor.token,
                               course_name: course.name, email: user.email,
                               lecture: new_lecture, section: new_section,
                               dropped: new_dropped, grade_policy: new_grade_policy }
        expect(response.response_code).to eq(200)
        msg = JSON.parse(response.body)

        expect(msg['lecture']).to eq(new_lecture)
        expect(msg['section']).to eq(new_section)
        expect(msg['dropped']).to eq(new_dropped)
        expect(msg['grade_policy']).to eq(new_grade_policy)
        cud = user.course_user_data.find_by(course:)
        expect(cud.lecture).to eq(new_lecture)
        expect(cud.section).to eq(new_section)
        expect(cud.dropped).to eq(new_dropped)
        expect(cud.grade_policy).to eq(new_grade_policy)
      end
    end
  end

  describe 'DELETE destroy' do
    include_context "api shared context"

    it_behaves_like "a CUD route", :delete, :destroy

    it_behaves_like "a CUD member route", :delete, :destroy

    context 'when user is valid' do
      it 'correctly drops the user' do
        cud = user.course_user_data.find_by(course:)
        cud.dropped = false
        cud.save!

        delete :destroy, params: { access_token: instructor_token_for_instructor.token,
                                   course_name: course.name, email: user.email }
        expect(response.response_code).to eq(200)

        cud = user.course_user_data.find_by(course:)
        expect(cud).not_to be_nil
        expect(cud.dropped).to be_truthy
      end

      it 'correctly drops the user even if the dropped arg is false' do
        cud = user.course_user_data.find_by(course:)
        cud.dropped = false
        cud.save!

        delete :destroy, params: { access_token: instructor_token_for_instructor.token,
                                   course_name: course.name, email: user.email, dropped: false }
        expect(response.response_code).to eq(200)

        cud = user.course_user_data.find_by(course:)
        expect(cud).not_to be_nil
        expect(cud.dropped).to be_truthy
      end

      it 'does not update other attributes' do
        cud = user.course_user_data.find_by(course:)
        old_lecture = cud.lecture
        new_lecture = "#{cud.lecture}4242"

        delete :destroy, params: { access_token: instructor_token_for_instructor.token,
                                   course_name: course.name,
                                   email: user.email,
                                   lecture: new_lecture }
        expect(response.response_code).to eq(200)

        cud = user.course_user_data.find_by(course:)
        expect(cud).not_to be_nil
        expect(cud.lecture).to eq(old_lecture)
      end
    end
  end
end
