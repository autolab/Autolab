RSpec.shared_context "api shared context" do
  all_users = CourseUserDatum.joins(:user).where("users.administrator" => false, :instructor => false, :course_assistant => false)
  let(:user) { all_users.offset(rand(all_users.count)).first.user }
  let(:course) { CourseUserDatum.where(user_id: user.id).first.course }
  let(:assessment) { course.assessments.offset(rand(course.assessments.count)).first }

  # default application with access to user_info and user_courses
  let!(:application) { Doorkeeper::Application.create! :name => "TestApp", :redirect_uri => "https://example.com", :scopes => "user_info user_courses" }
  let!(:token) { Doorkeeper::AccessToken.create! :application_id => application.id, :resource_owner_id => user.id, :scopes => "user_info user_courses" }

  # user_info app
  let!(:user_info_application) { Doorkeeper::Application.create! :name => "UserInfoApp", :redirect_uri => "https://user-info-example.com", :scopes => "user_info" }
  let!(:user_info_token) { Doorkeeper::AccessToken.create! :application_id => user_info_application.id, :resource_owner_id => user.id, :scopes => "user_info" }
end