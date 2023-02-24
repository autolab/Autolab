require "rails_helper"
include ControllerMacros
RSpec.describe AssessmentsController, type: :controller do
  describe "GET index" do
    it "assigns all assessments as @assessments" do
      assessment = build(:assessment)
      FileUtils.mkdir_p assessment.handin_directory_path
      assessment.save
    end
  end

  describe "Export and Import Roundtrip" do
    context "when user is Instructor" do
      let!(:course_hash) do
        create_course_with_many_students
      end
      before(:each) do
        instructor = get_instructor_by_cid(course_hash[:course].id)
        sign_in(instructor)
      end
      it "successfully imports an exported assessment" do
        get :export,
            params: {course_name: course_hash[:course].name, name: course_hash[:assessment].name}
        expect(response).to have_http_status(200)
        file = File.binwrite("tmp/test.tar", response.parsed_body)
        File.open("tmp/test.tar",  encoding: 'ASCII-8BIT') do |file|
          Gem::Package::TarReader.new(file) do |tar|
            tar.seek("#{course_hash[:assessment].name}/#{course_hash[:assessment].name}.yml") do |entry|
              test = YAML.safe_load(entry.read())
              expect(test["general"]["name"]).to eq(course_hash[:assessment].name)
            end
          end
        end
      end
    end
  end
end
