require "rails_helper"
include ControllerMacros
require_relative 'controllers_shared_context'

RSpec.describe ExtensionsController, type: :controller do
  render_views

  shared_examples "extensions_success" do
    it "renders successfully" do
      sign_in(user)
      get :index, params: { course_name: @course.name, assessment_name: @assessment.name }
      expect(response).to be_successful
      expect(response.body).to match(/Current Extensions/m)
    end
  end

  shared_examples "extensions_failure" do |login: false|
    it "renders with failure" do
      sign_in(user) if login
      get :index, params: { course_name: @course.name, assessment_name: @assessment.name }
      expect(response).not_to be_successful
      expect(response.body).not_to match(/Current Extensions/m)
    end
  end

  describe "index" do
    include_context "controllers shared context"
    context "when user is Autolab admin" do
      it_behaves_like "extensions_success" do
        let!(:user) { admin_user }
      end
    end

    context "when user is Autolab instructor" do
      it_behaves_like "extensions_success" do
        let!(:user) { instructor_user }
      end

      it "renders updates on create and delete" do
        sign_in(instructor_user)
        student_user = @students[0]
        extension_days = 10
        post :create, params: {
          course_name: @course.name,
          assessment_name: @assessment.name,
          course_user_data: student_user.id,
          extension: {
            days: extension_days,
            infinite: false
          }
        }
        get :index, params: { course_name: @course.name, assessment_name: @assessment.name }
        expect(response).to be_successful
        expect(response.body).to match(/Current Extensions \(1\)/m)
        expect(response.body).to match(/#{student_user.email}/m)
        expect(response.body).to match(/#{extension_days} days/m)

        extension = Extension.find_by(assessment_id: @assessment.id,
                                      course_user_datum_id: student_user.id)
        delete :destroy, params: {
          course_name: @course.name,
          assessment_name: @assessment.name,
          id: extension.id
        }
        get :index, params: { course_name: @course.name, assessment_name: @assessment.name }
        expect(response).to be_successful
        expect(response.body).to match(/Current Extensions \(0\)/m)
        expect(response.body).to match(/There are currently no extensions for this assessment/m)
      end
    end

    context "when user is Autolab user" do
      it_behaves_like "extensions_failure", login: true do
        let!(:user) { student_user }
      end
    end

    context "when user is not logged in" do
      it_behaves_like "extensions_failure", login: false do
        let!(:user) { student_user }
      end
    end
  end

  describe "create" do
    include_context "controllers shared context"
    context "when instructor" do
      before(:each) do
        sign_in(instructor_user)
      end
      it "flashes error when no users specified" do
        post :create, params: { course_name: @course.name, assessment_name: @assessment.name }
        expect(response).to have_http_status(302)
        expect(flash[:error]).to match(/No users were specified!/m)
      end

      it "flashes error when user not in course specified" do
        valid_uid = User.maximum(:id)
        invalid_uid = valid_uid + 1
        cud = "#{valid_uid},#{invalid_uid}"
        post :create,
             params: { course_name: @course.name, assessment_name: @assessment.name,
                       course_user_data: cud }
        expect(response).to have_http_status(302)
        expect(flash[:error]).to match(/No user with id #{invalid_uid} was found for this course./m)
      end

      it "adds new extension and updates existing extension successfully" do
        uid = @students[0].id
        post :create, params: {
          course_name: @course.name,
          assessment_name: @assessment.name,
          course_user_data: uid,
          extension: {
            days: 10,
            infinite: false
          }
        }
        extension = Extension.find_by(assessment_id: @assessment.id, course_user_datum_id: uid)
        expect(extension.days).to equal(10)
        expect(extension.infinite).to be false

        post :create, params: {
          course_name: @course.name,
          assessment_name: @assessment.name,
          course_user_data: uid,
          extension: {
            days: 5,
            infinite: true
          }
        }
        extension = Extension.find_by(assessment_id: @assessment.id, course_user_datum_id: uid)
        expect(extension.days).to equal(5)
        expect(extension.infinite).to be true
      end

      it "flashes error on invalid record" do
        post :create, params: {
          course_name: @course.name,
          assessment_name: @assessment.name,
          course_user_data: @students[0].id,
          extension: {
            days: [],
            infinite: false
          }
        }
        expect(flash[:error]).to match(/Validation failed/m)
      end
    end
  end

  describe "destroy" do
    include_context "controllers shared context"
    context "when instructor" do
      it "deletes extension successfully" do
        sign_in(instructor_user)
        uid = @students[0].id
        post :create, params: {
          course_name: @course.name,
          assessment_name: @assessment.name,
          course_user_data: uid,
          extension: {
            days: 10,
            infinite: false
          }
        }
        extension = Extension.find_by(assessment_id: @assessment.id, course_user_datum_id: uid)
        expect(extension.days).to equal(10)
        expect(extension.infinite).to be false

        delete :destroy, params: {
          course_name: @course.name,
          assessment_name: @assessment.name,
          id: extension.id
        }
        extension = Extension.find_by(assessment_id: @assessment.id, course_user_datum_id: uid)
        expect(extension).to be_nil
      end
    end
  end
end
