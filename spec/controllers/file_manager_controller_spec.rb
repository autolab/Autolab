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

    context "when user is Autolab user" do
      let!(:u) { student_user }
      it_behaves_like "index_success"
      it_behaves_like "index_empty"
    end

    context "when user is not logged in" do
      let!(:u) { instructor_user }
      it_behaves_like "index_failure", login: false
      it_behaves_like "rename_failure", login: false
      it_behaves_like "path_failure", login: false
    end
  end
end
