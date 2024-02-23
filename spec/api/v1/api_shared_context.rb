require_relative("../../support/controller_macros")

RSpec.shared_context "api shared context" do
  let!(:course) do
    create_autograded_course_with_users
    @course
  end
  after(:each) do
    delete_course_files(@course)
  end
  let(:user) {
    all_users = CourseUserDatum.joins(:user).where(
      :course => course, "users.administrator" => false,
      :instructor => false, :course_assistant => false
    )
    all_users.offset(rand(all_users.count)).first.user
  }
  let(:released_assessments) { course.assessments.where('start_at < ?', DateTime.now) }
  let(:assessment) { released_assessments.offset(rand(released_assessments.count)).first }
  let(:msg) { JSON.parse(response.body) }

  # default application with access to user_info and user_courses
  let!(:application) {
    Doorkeeper::Application.create! name: "TestApp", redirect_uri: "https://example.com",
                                    scopes: "user_info user_courses"
  }
  let!(:token) {
    Doorkeeper::AccessToken.create! application_id: application.id, resource_owner_id: user.id,
                                    scopes: "user_info user_courses"
  }

  # user_info app
  let!(:user_info_application) {
    Doorkeeper::Application.create! name: "UserInfoApp",
                                    redirect_uri: "https://user-info-example.com",
                                    scopes: "user_info"
  }
  let!(:user_info_token) {
    Doorkeeper::AccessToken.create! application_id: user_info_application.id,
                                    resource_owner_id: user.id, scopes: "user_info"
  }

  # device_flow app
  # The redirect_uri is just a stub. It is not involved in the test.
  let!(:df_application) {
    Doorkeeper::Application.create!(
      name: "CLIApp", redirect_uri: "https://localhost:3000/device_flow_auth_cb",
      scopes: "user_info user_courses"
    )
  }

  # admin-related
  let(:admin_user) { User.where(administrator: true).first }
  let!(:admin_application) {
    Doorkeeper::Application.create!(
      name: "AdminApp", redirect_uri: "https://admin.example.com",
      scopes: "user_info user_courses user_scores user_submit admin_all instructor_all"
    )
  }
  let!(:admin_token_for_admin) {
    Doorkeeper::AccessToken.create!(
      application_id: admin_application.id,
      resource_owner_id: admin_user.id,
      scopes: "user_info user_courses user_scores user_submit admin_all instructor_all"
    )
  }
  let!(:admin_token_for_user) {
    Doorkeeper::AccessToken.create!(
      application_id: admin_application.id, resource_owner_id: user.id,
      scopes: "user_info user_courses user_scores user_submit admin_all instructor_all"
    )
  }

  # instructor-related
  let(:instructor) { admin_user }
  let!(:instructor_application) {
    Doorkeeper::Application.create!(
      name: "InstructorApp",
      redirect_uri: "https://instructor.example.com",
      scopes: "user_info user_courses user_scores user_submit instructor_all"
    )
  }
  let!(:instructor_token_for_instructor){
    Doorkeeper::AccessToken.create!(
      application_id: instructor_application.id,
      resource_owner_id: instructor.id,
      scopes: "user_info user_courses user_scores user_submit instructor_all"
    )
  }
  let!(:instructor_token_for_user){
    Doorkeeper::AccessToken.create!(
      application_id: instructor_application.id,
      resource_owner_id: user.id,
      scopes: "user_info user_courses user_scores user_submit instructor_all"
    )
  }
end

RSpec.shared_context "api handin context" do
  let(:course) do
    create_autograded_course_with_users
    @course
  end
  before :each do
    # The adder.py file to hand in
    @handin_file = fixture_file_upload('handins/adder.py', 'text/plain')
    # The AutoPopulate Course
    @ap_course = course
    @ap_cud = CourseUserDatum.where(course: @ap_course, instructor: false,
                                    course_assistant: false).first
    @ap_student = @ap_cud.user
    # The adder.py Assessment
    @adder_asm = Assessment.where(course: @ap_course).first
  end
  after(:each) do
    delete_course_files(@course)
  end

  let!(:bad_application) {
    Doorkeeper::Application.create!(
      name: "TestApp",
      redirect_uri: "https://example.com",
      scopes: "user_info user_courses"
    )
  }
  let!(:bad_token) {
    Doorkeeper::AccessToken.create!(
      application_id: application.id,
      resource_owner_id: @ap_student.id,
      scopes: "user_info user_courses"
    )
  }

  let!(:application) {
    Doorkeeper::Application.create!(
      name: "TestApp",
      redirect_uri: "https://example.com",
      scopes: "user_info user_submit"
    )
  }
  let!(:token) {
    Doorkeeper::AccessToken.create!(
      application_id: application.id,
      resource_owner_id: @ap_student.id,
      scopes: "user_info user_submit"
    )
  }
end
