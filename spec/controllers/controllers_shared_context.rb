include ControllerMacros

RSpec.shared_context "controllers shared context" do
  let!(:course_hash) do
    create_course_with_users_as_hash
  end
  let(:course) do
    course_hash[:course]
  end
  let(:admin_user) do
    course_hash[:admin_user]
  end
  let(:instructor_user) do
    course_hash[:instructor_user]
  end
  let(:course_assistant_user) do
    course_hash[:course_assistant_user]
  end
  let(:student_user) do
    course_hash[:students_cud].first
  end
  let(:assessment) do
    course_hash[:assessment]
  end

  after(:each) do
    delete_course_files(course_hash[:course])
  end
end
