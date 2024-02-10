require "rails_helper"
include ControllerMacros
RSpec.describe AssessmentsController, type: :controller do
  render_views
  describe "GET index" do
    it "assigns all assessments as @assessments" do
      assessment = build(:assessment)
      FileUtils.mkdir_p assessment.handin_directory_path
      assessment.save
    end
  end

  describe "Create Assessment" do
    context "when user is Instructor" do
      let!(:course_hash) do
        create_course_with_users_as_hash
      end
      let!(:stub_assessment) do
        stubAssessment = build(:assessment)
        stubAssessment.display_name = "../"
        stubAssessment.name = ""
        stubAssessment.save
        stubAssessment
      end
      let!(:stub_assessment2) do
        stubAssessment = build(:assessment)
        stubAssessment.display_name = "..courses-okay_beautiful"
        stubAssessment.name = ""
        stubAssessment.save
        stubAssessment
      end
      before(:each) do
        instructor = get_instructor_by_cid(course_hash[:course].id)
        sign_in(instructor)
        allow_any_instance_of(AssessmentsController).to(
          receive(:new_assessment_params).and_return(nil)
        )
      end
      it "rejects bad assessment display name" do
        allow_any_instance_of(ActiveRecord::Associations::CollectionProxy).to(
          receive(:new).and_return(stub_assessment)
        )

        post :create, params: { course_name: course_hash[:course].name }
        expect(flash[:error]).to be_present
        expect(flash[:error]).to(
          match(/Assessment name is blank or contains disallowed characters/m)
        )
        expect(Assessment.find_by(name: "courses")).to eql(nil)
      end
      it "sanitizes assessment display name" do
        allow_any_instance_of( ActiveRecord::Associations::CollectionProxy).to(
          receive(:new).and_return(stub_assessment2)
        )
        post :create, params: { course_name: course_hash[:course].name,
                                display_name: stub_assessment2.display_name }
        expect(response).to have_http_status(302)
        expect(flash[:success]).to be_present
        expect(Assessment.find_by(name: "courses-okay_beautiful")).not_to eql(nil)
      end
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
        File.open("tmp/test.tar", encoding: 'ASCII-8BIT') do |file|
          Gem::Package::TarReader.new(file) do |tar|
            tar.seek("#{course_hash[:assessment].name}/#{course_hash[:assessment].name}.yml") do
              |entry|
              test = YAML.safe_load(entry.read)
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
            end
          end
        end
        file = Rack::Test::UploadedFile.new("tmp/test.tar")
        post :importAsmtFromTar, params: { course_name: course_2_hash[:course].name,
                                           name: course_2_hash[:assessment].name,
                                           tarFile: file }

        expect(response).to have_http_status(302)
        expect(flash[:success]).to be_present
        expect(File).to exist(course_2_hash[:assessment].unique_config_file_path)
        config_source = File.open(course_2_hash[:assessment].unique_config_file_path,
                                  "r", &:read)
        expect config_source.include? course_2_hash[:assessment].unique_config_module_name
        FileUtils.rm("tmp/test.tar")
        # cleanup assessmentConfig
        FileUtils.rm(course_2_hash[:assessment].unique_config_file_path)
      end
      it "properly dumps imported data" do
        file = fixture_file_upload("assessments/all-fields-filled.tar")
        post :importAsmtFromTar, params: { course_name: course_2_hash[:course].name,
                                           tarFile: file }
        expect(response).to have_http_status(302)
        expect(flash[:success]).to be_present
        File.open(Rails.root.join(file_fixture_path, "assessments", "all-fields-filled.tar"),
                  encoding: 'ASCII-8BIT') do |exportTarFile|
          Gem::Package::TarReader.new(exportTarFile) do |tar|
            tar.seek("hellotar-2/hellotar-2.yml") do |entry|
              export_yml = YAML.safe_load(entry.read)
              File.open(Rails.root.join("courses", course_2_hash[:course].name, "hellotar-2",
                                        "hellotar-2.yml")) do |importFile|
                import_yml = YAML.safe_load(importFile.read)
                puts(Rails.root.join("courses", course_2_hash[:course].name, "hellotar-2",
                                     "hellotar-2.yml"))
                # the yml should contain exactly the same info, in the same order, per dump_yaml
                expect(
                  export_yml
                ).to eq(import_yml)
              end
            end
          end
        end
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
      it "handles legal assessment name" do
        file = fixture_file_upload("assessments/homework02-legal-name-no-config.tar")
        post :importAsmtFromTar, params: { course_name: course_2_hash[:course].name,
                                           name: course_2_hash[:assessment].name,
                                           tarFile: file }
        expect(response).to have_http_status(302)
        expect(flash[:success]).to be_present
      end
      it "handles mismatched module name" do
        file = fixture_file_upload("assessments/homework02-module-mismatch.tar")
        post :importAsmtFromTar, params: { course_name: course_2_hash[:course].name,
                                           name: course_2_hash[:assessment].name,
                                           tarFile: file }
        expect(response).to have_http_status(302)
        expect(flash[:success]).to be_present
        expect(File).to exist(course_2_hash[:assessment].unique_config_file_path)
        config_source = File.open(course_2_hash[:assessment].unique_config_file_path,
                                  "r", &:read)
        expect config_source.include? course_2_hash[:assessment].unique_config_module_name
        # cleanup assessmentConfig
        FileUtils.rm(course_2_hash[:assessment].unique_config_file_path)
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
      it "handles existing assessment reupload" do
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
        expect(flash[:success]).to be_present
        expect(flash[:success]).to match(/IMPORTANT:/m)
      end
    end
  end
end
