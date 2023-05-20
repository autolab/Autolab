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
        create_course_with_users_as_hash
      end
      let!(:course_2_hash) do
        create_course_with_users_as_hash(asmt_name: "newassessment")
      end
      before(:each) do
        instructor = get_instructor_by_cid(course_hash[:course].id)
        sign_in(instructor)
      end

      it "successfully imports an exported assessment" do
        get :export,
            params: { course_name: course_hash[:course].name, name: course_hash[:assessment].name }
        expect(response).to have_http_status(200)
        File.binwrite("tmp/test.tar", response.parsed_body)
        File.open("tmp/test.tar",  encoding: 'ASCII-8BIT') do |file|
          Gem::Package::TarReader.new(file) do |tar|
            tar.seek("#{course_hash[:assessment].name}/#{course_hash[:assessment].name}.yml") do
              |entry|
              test = YAML.safe_load(entry.read)
              expect(
                test["general"]["name"]
              ).to eq(course_hash[:assessment].name)
              expect(
                test["general"]["display_name"]
              ).to eq(course_hash[:assessment].display_name)
              expect(
                test["general"]["github_submission_enabled"]
              ).to eq(course_hash[:assessment].github_submission_enabled)
              expect(test["general"]["group_size"]).to eq(course_hash[:assessment].group_size)
              expect(test["dates"]["due_at"]).to eq(course_hash[:assessment].due_at.to_s)
              expect(test["dates"]["start_at"]).to eq(course_hash[:assessment].start_at.to_s)
              expect(test["dates"]["end_at"]).to eq(course_hash[:assessment].end_at.to_s)
              expect(
                test["dates"]["grading_deadline"]
              ).to eq(course_hash[:assessment].grading_deadline.to_s)
            end
          end
        end
        file = Rack::Test::UploadedFile.new("tmp/test.tar")
        post :importAsmtFromTar, params: { course_name: course_2_hash[:course].name,
                                           name: course_2_hash[:assessment].name,
                                           tarFile: file }

        expect(response).to have_http_status(302)
        expect(flash[:success]).to be_present
        FileUtils.rm("tmp/test.tar")
      end
      it "handles nil tarfile" do
        post :importAsmtFromTar, params: { course_name: course_2_hash[:course].name,
                                           name: course_2_hash[:assessment].name }
        expect(response).to have_http_status(302)
        expect(flash[:error]).to be_present
        expect(flash[:error]).to match(/Please select an assessment tarball for uploading/m)
      end
      it "handles bad tarfile" do
        post :importAsmtFromTar, params: { course_name: course_2_hash[:course].name,
                                           name: course_2_hash[:assessment].name,
                                           tarFile: nil }
        expect(response).to have_http_status(302)
        expect(flash[:error]).to be_present
        expect(flash[:error]).to match(/Error while reading the tarball/m)
      end
      it "handles yaml file name mismatch" do
        file = fixture_file_upload("assessments/homework02-file-mismatch.tar")
        post :importAsmtFromTar, params: { course_name: course_2_hash[:course].name,
                                           name: course_2_hash[:assessment].name,
                                           tarFile: file }
        expect(response).to have_http_status(302)
        expect(flash[:error]).to be_present
        expect(flash[:error]).to match(/Assessment yml file/m)
      end
      it "handles illegal assessment name" do
        file = fixture_file_upload("assessments/homework02-illegal-assessment-name.tar")
        post :importAsmtFromTar, params: { course_name: course_2_hash[:course].name,
                                           name: course_2_hash[:assessment].name,
                                           tarFile: file }
        expect(response).to have_http_status(302)
        expect(flash[:error]).to be_present
        expect(flash[:error]).to match(/invalid/m)
      end
      it "handles broken yaml file" do
        file = fixture_file_upload("assessments/homework02-yaml-name-field-wrong.tar")
        post :importAsmtFromTar, params: { course_name: course_2_hash[:course].name,
                                           name: course_2_hash[:assessment].name,
                                           tarFile: file }
        expect(response).to have_http_status(302)
        expect(flash[:error]).to be_present
        expect(flash[:error]).to match(/Error loading yaml/m)
      end
      it "handles mismatched module name" do
        file = fixture_file_upload("assessments/homework02-module-mismatch.tar")
        post :importAsmtFromTar, params: { course_name: course_2_hash[:course].name,
                                           name: course_2_hash[:assessment].name,
                                           tarFile: file }
        expect(response).to have_http_status(302)
        expect(flash[:error]).to be_present
        expect(flash[:error]).to match(/Error loading config module/m)
      end
      it "handles module with bad syntax" do
        file = fixture_file_upload("assessments/homework02_badsyntax.tar")
        post :importAsmtFromTar, params: { course_name: course_2_hash[:course].name,
                                           name: course_2_hash[:assessment].name,
                                           tarFile: file }
        expect(response).to have_http_status(302)
        expect(flash[:error]).to be_present
        expect(flash[:error]).to match(/syntax error/m)
      end
      it "handles mismatched same name error" do
        file = fixture_file_upload("assessments/homework02-correct.tar")
        post :importAsmtFromTar, params: { course_name: course_2_hash[:course].name,
                                           name: course_2_hash[:assessment].name,
                                           tarFile: file }
        expect(response).to have_http_status(302)
        expect(flash[:success]).to be_present
        post :importAsmtFromTar, params: { course_name: course_2_hash[:course].name,
                                           name: course_2_hash[:assessment].name,
                                           tarFile: file }
        expect(response).to have_http_status(302)
        expect(flash[:error]).to be_present
        expect(flash[:error]).to match(/same name/m)
      end
    end
  end
end
