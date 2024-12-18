require "rails_helper"
include ControllerMacros
require_relative "controllers_shared_context"

RSpec.describe FileManagerController, type: :controller do
  render_views

  shared_examples "index_success" do |login: true|
    before(:each) { sign_in(u) if login }
    it "renders successfully" do
      get :index
      expect(response).to be_successful
      doc = Nokogiri::HTML(response.body)
      expect(doc).to have_selector("th", text: "Filename")
      expect(doc).to have_selector("th", text: "Bytes")
      expect(doc).to have_selector("th", text: "Date")
      expect(doc).to have_selector("th", text: "Rename")
      expect(doc).to have_selector("th", text: "Delete")
      expect(doc).to have_selector("span", text: "Download Selected")
      expect(doc).to have_selector("span", text: "Create Folder")
      expect(doc).to have_selector("span", text: "Download Selected")
      expect(doc).to have_selector("span", text: "Delete Selected")
    end
  end

  shared_examples "unauthorized_access" do |login: true|
    before(:each) { sign_in(u) if login }
    it "redirects with error when accessing unauthorized path" do
      get :index, params: { path: unauthorized_path }
      expect(response).to redirect_to(root_path)
      expect(flash[:error]).to eq("You are not authorized to view this path")
    end
  end

  shared_examples "index_empty" do |login: true|
    before(:each) { sign_in(u) if login }
    it "renders empty file manager" do
      get :index
      doc = Nokogiri::HTML(response.body)
      expect(doc).to_not have_selector("*", text: "test_course")
    end
  end

  shared_examples "index_not_empty" do |login: true|
    before(:each) { sign_in(u) if login }
    it "renders empty file manager" do
      get :index
      doc = Nokogiri::HTML(response.body)
      expect(doc).to have_selector("span", text: "test_course")
    end
  end

  shared_examples "index_failure" do |login: true|
    before(:each) { sign_in(u) if login }
    it "renders unsuccessfully" do
      get :index
      expect(response).to_not be_successful
    end
  end

  shared_examples "path_success" do |login: true|
    before(:each) { sign_in(u) if login }
    it "path links successfully" do
      get :index, params: { path: "test_course_1" }
      expect(response).to have_http_status(:success)
    end
  end

  shared_examples "path_failure" do |login: true|
    before(:each) { sign_in(u) if login }
    it "path links unsuccessfully" do
      get :index, params: { path: "test_course_1" }
      expect(response).to_not be_successful
    end
  end

  shared_examples "rename_success" do |login: true|
    before(:each) { sign_in(u) if login }
    it "renames successfully" do
      put :rename, params: { path: "test_course_1/testassessment", new_name: "testassessment1" }
      expect(response).to be_successful
    end
  end

  shared_examples "rename_failure" do |login: true|
    before(:each) { sign_in(u) if login }
    it "renames unsuccessfully" do
      put :rename, params: { path: "test_course_1/testassessment", new_name: "testassessment1" }
      expect(response).to_not be_successful
    end
  end

  describe "#index" do
    include_context "controllers shared context"
    context "when user is Autolab instructor" do
      let!(:u) { instructor_user }
      it_behaves_like "index_success"
      it_behaves_like "index_not_empty"
      it_behaves_like "rename_success"
      it_behaves_like "path_success"
    end

    context "when user is Autolab student" do
      let!(:u) { student_user }
      it_behaves_like "index_failure"
    end

    context "when user is not logged in" do
      let!(:u) { instructor_user }
      it_behaves_like "index_failure", login: false
      it_behaves_like "rename_failure", login: false
      it_behaves_like "path_failure", login: false
    end

    context "when user is not an instructor of the course" do
      let(:unauthorized_path) { "#{@course.name}/secret_folder" }
      let!(:instructor) { instructor_user }

      before(:each) do
        sign_in(instructor)
        # Set up the BASE_DIRECTORY and create the course directory
        @base_dir = Dir.mktmpdir
        stub_const('FileManagerController::BASE_DIRECTORY', Pathname.new(@base_dir))
        FileUtils.mkdir_p(File.join(@base_dir, unauthorized_path))
        # Ensure that the controller uses the modified BASE_DIRECTORY
        allow(FileManagerController).to receive(:const_get)
                                    .with(:BASE_DIRECTORY)
          .and_return(Pathname.new(@base_dir))
      end

      let!(:u) { student_user }
      it_behaves_like "unauthorized_access"

      after(:each) do
        delete_course_files(course_hash[:course])
      end
    end
  end

  describe "POST #delete" do
    include_context "controllers shared context"

    context "when user is an instructor" do
      let!(:instructor) { instructor_user }
      let!(:student) { student_user }
      let!(:file_path) { "#{@course.name}/test_file.txt" }
      before(:each) do
        sign_in(instructor)
        @base_dir = Dir.mktmpdir
        stub_const('FileManagerController::BASE_DIRECTORY', Pathname.new(@base_dir))
        FileUtils.mkdir_p(File.join(@base_dir, @course.name))
        File.write(File.join(@base_dir, file_path), 'Content')
        allow(FileManagerController).to receive(:const_get)
                                    .with(:BASE_DIRECTORY)
          .and_return(Pathname.new(@base_dir))
      end

      after(:each) do
        FileUtils.remove_entry_secure(@base_dir)
      end

      it "deletes the file successfully" do
        sign_in(instructor)
        post :delete, params: { path: file_path }
        expect(File.exist?(File.join(@base_dir, file_path))).to be_falsey
      end
    end

    context "when user is not an instructor" do
      let!(:student) { student_user }
      let!(:instructor) { instructor_user }
      let!(:file_path) { "#{@course.name}/test_file.txt" }
      before(:each) do
        sign_in(instructor)
        @base_dir = Dir.mktmpdir
        stub_const('FileManagerController::BASE_DIRECTORY', Pathname.new(@base_dir))
        FileUtils.mkdir_p(File.join(@base_dir, @course.name))
        File.write(File.join(@base_dir, file_path), 'Content')
        allow(FileManagerController).to receive(:const_get)
                                    .with(:BASE_DIRECTORY)
          .and_return(Pathname.new(@base_dir))
      end

      after(:each) do
        FileUtils.remove_entry_secure(@base_dir)
      end

      it "does not allow delete and redirects with error" do
        sign_in(student)
        post :delete, params: { path: file_path }
        expect(response).to redirect_to(root_path)
        expect(flash[:error]).to eq("You are not authorized to delete this")
        expect(File.exist?(File.join(@base_dir, file_path))).to be_truthy
      end
    end
  end

  describe "PUT #rename" do
    include_context "controllers shared context"

    context "when user is an instructor" do
      let!(:student) { student_user }
      let!(:instructor) { instructor_user }
      let!(:file_path) { "#{@course.name}/test_file.txt" }
      let!(:new_name) { 'renamed_file.txt' }

      before(:each) do
        sign_in(instructor)
        @base_dir = Dir.mktmpdir
        stub_const('FileManagerController::BASE_DIRECTORY', Pathname.new(@base_dir))
        FileUtils.mkdir_p(File.join(@base_dir, @course.name))
        File.write(File.join(@base_dir, file_path), 'Content')
      end

      after(:each) do
        FileUtils.remove_entry_secure(@base_dir)
      end

      it "renames the file successfully" do
        sign_in(instructor)
        put :rename, params: { relative_path: file_path, new_name:, path: file_path }
        expect(flash[:success]).to eq("Successfully renamed file to #{new_name}")
        expect(File.exist?(File.join(@base_dir, @course.name, new_name))).to be_truthy
        expect(File.exist?(File.join(@base_dir, file_path))).to be_falsey
      end
    end

    context "when user is not an instructor" do
      let!(:student) { student_user }
      let!(:instructor) { instructor_user }
      let!(:file_path) { "#{@course.name}/test_file.txt" }
      let!(:new_name) { 'renamed_file.txt' }

      before(:each) do
        sign_in(instructor)
        @base_dir = Dir.mktmpdir
        stub_const('FileManagerController::BASE_DIRECTORY', Pathname.new(@base_dir))
        FileUtils.mkdir_p(File.join(@base_dir, @course.name))
        File.write(File.join(@base_dir, file_path), 'Content')
      end

      after(:each) do
        FileUtils.remove_entry_secure(@base_dir)
      end

      it "does not allow rename and redirects with error" do
        sign_in(student)
        put :rename, params: { relative_path: file_path, new_name:, path: file_path }
        expect(response).to redirect_to(root_path)
        expect(flash[:error]).to eq("You are not authorized to rename this path")
        expect(File.exist?(File.join(@base_dir, course.name, new_name))).to be_falsey
        expect(File.exist?(File.join(@base_dir, file_path))).to be_truthy
      end
    end
  end

  describe "POST #upload" do
    include_context "controllers shared context"

    context "when user is an instructor" do
      let!(:student) { student_user }
      let!(:instructor) { instructor_user }
      let!(:file_path) { @course.name }

      before(:each) do
        sign_in(instructor)
        @base_dir = Dir.mktmpdir
        stub_const('FileManagerController::BASE_DIRECTORY', Pathname.new(@base_dir))
        FileUtils.mkdir_p(File.join(@base_dir, file_path))
      end

      after(:each) do
        FileUtils.remove_entry_secure(@base_dir)
      end

      it "creates a folder successfully" do
        sign_in(instructor)
        post :upload, params: { path: file_path, name: 'files' }
        expect(Dir.exist?(File.join(@base_dir, file_path, 'files'))).to be_truthy
      end

      it "uploads a file successfully" do
        sign_in(instructor)
        file = fixture_file_upload('files/test_file.txt', 'text/plain')
        post :upload, params: { path: file_path, file:, name: "" }
        expect(File.exist?(File.join(@base_dir, file_path, 'test_file.txt'))).to be_truthy
      end
    end

    context "when user is not an instructor" do
      let!(:student) { student_user }
      let!(:instructor) { instructor_user }
      let!(:file_path) { @course.name }

      before(:each) do
        sign_in(instructor)
        @base_dir = Dir.mktmpdir
        stub_const('FileManagerController::BASE_DIRECTORY', Pathname.new(@base_dir))
        FileUtils.mkdir_p(File.join(@base_dir, file_path))
      end

      after(:each) do
        FileUtils.remove_entry_secure(@base_dir)
      end

      it "does not allow folder creation and redirects with error" do
        sign_in(student)
        post :upload, params: { path: file_path, name: 'files' }
        expect(response).to redirect_to(root_path)
        expect(flash[:error]).to eq("You are not authorized to upload files at this path")
        expect(Dir.exist?(File.join(@base_dir, file_path, 'files'))).to be_falsey
      end

      it "does not allow file upload and redirects with error" do
        sign_in(student)
        file = fixture_file_upload('files/test_file.txt', 'text/plain')
        post :upload, params: { path: file_path, file: }
        expect(response).to redirect_to(root_path)
        expect(flash[:error]).to eq("You are not authorized to upload files at this path")
        expect(File.exist?(File.join(@base_dir, file_path, 'test_file.txt'))).to be_falsey
      end
    end
  end

  describe "GET #download_tar" do
    include_context "controllers shared context"

    let(:file_content_type) { 'text/plain' }
    let(:tar_content_type) { 'application/x-tar' }

    context "when user is an instructor" do
      let!(:student) { student_user }
      let!(:instructor) { instructor_user }
      let!(:dir_path) { "#{@course.name}/sample_dir" }
      let!(:file_path) { "#{@course.name}/sample_dir/file.txt" }

      before(:each) do
        sign_in(instructor)
        @base_dir = Dir.mktmpdir
        stub_const('FileManagerController::BASE_DIRECTORY', Pathname.new(@base_dir))
        FileUtils.mkdir_p(File.join(@base_dir, dir_path))
        File.write(File.join(@base_dir, file_path), 'Content')
      end

      after(:each) do
        FileUtils.remove_entry_secure(@base_dir)
      end

      it "downloads the directory as a tar file" do
        sign_in(instructor)
        get :download_tar, params: { path: "autopopulated/test/#{dir_path}" }
        expect(response.content_type).to eq(tar_content_type)
        expect(response.body).not_to be_empty
      end

      it "downloads a file successfully" do
        sign_in(instructor)
        get :download_tar, params: { path: "autopopulated/test/#{file_path}" }
        expect(response.content_type).to match(file_content_type)
        expect(response.body).not_to be_empty
      end

      it "returns error when attempting to download root directory" do
        sign_in(instructor)
        get :download_tar, params: { path: '' }
        expect(response).to redirect_to(root_path)
        expect(flash[:error]).to eq("You are not authorized to download attachments at this path")
      end
    end

    context "when user is not an instructor" do
      let!(:student) { student_user }
      let!(:instructor) { instructor_user }
      let!(:dir_path) { "#{@course.name}/sample_dir" }
      let!(:file_path) { "#{@course.name}/sample_dir/file.txt" }

      before(:each) do
        sign_in(instructor)
        @base_dir = Dir.mktmpdir
        stub_const('FileManagerController::BASE_DIRECTORY', Pathname.new(@base_dir))
        FileUtils.mkdir_p(File.join(@base_dir, dir_path))
        File.write(File.join(@base_dir, file_path), 'Content')
      end

      after(:each) do
        FileUtils.remove_entry_secure(@base_dir)
      end

      it "does not allow directory download and redirects with error" do
        sign_in(student)
        get :download_tar, params: { path: "autopopulated/test/#{dir_path}" }
        expect(response).to redirect_to(root_path)
        expect(flash[:error]).to eq("You are not authorized to download attachments at this path")
      end

      it "does not allow file download and redirects with error" do
        sign_in(student)
        get :download_tar, params: { path: "autopopulated/test/#{file_path}" }
        expect(response).to redirect_to(root_path)
        expect(flash[:error]).to eq("You are not authorized to download attachments at this path")
      end
    end
  end
end
