require "rails_helper"

RSpec.describe AutogradersController, type: :controller do
  render_views

  describe "#create" do

    user_id = get_admin
    login_as(user_id)
    cud = get_first_cud_by_uid(user_id)
    cid = get_course_id_by_uid(user_id)
    course_name = Course.find(cid).name
    assessment_id = get_first_aid_by_cud(cud)
    assessment_name = Assessment.find(assessment_id).name

    it "creates an autograder" do
      expect{post :create, params: {course_name: course_name, assessment_name: assessment_name}}.to change{Autograder.count}.by(1)
    end

    it "redirects to edit" do
      post :create, params: {course_name: course_name, assessment_name: assessment_name}
      expect(response).to redirect_to(edit_course_assessment_autograder_path(course_name, assessment_name))
      expect(flash[:success]).to eq("Autograder Created")
    end

    it "renders with failure" do
      allow_any_instance_of(Autograder).to receive(:save).and_return(false)
      post :create, params: {course_name: course_name, assessment_name: assessment_name}
      expect(response).to redirect_to(edit_course_assessment_path(course_name, assessment_name))
      expect(flash[:error]).to eq("Autograder could not be created")
    end

  end

  describe "#edit" do
    user_id = get_admin
    login_as(user_id)
    cud = get_first_cud_by_uid(user_id)
    cid = get_course_id_by_uid(user_id)
    course_name = Course.find(cid).name
    assessment_id = get_first_aid_by_cud(cud)
    assessment_name = Assessment.find(assessment_id).name
    # create an autograder
    Autograder.new(assessment_id: assessment_id, autograde_timeout: 180,
                   autograde_image: "autograding_image", release_score: true).save

    it "renders successfully" do
      get :edit, params: {course_name: course_name, assessment_name: assessment_name}
      expect(response).to be_successful
      expect(response.body).to match(/Autograder Settings/m)
    end

  end

  describe "#update" do
    user_id = get_admin
    login_as(user_id)
    cud = get_first_cud_by_uid(user_id)
    cid = get_course_id_by_uid(user_id)
    course_name = Course.find(cid).name
    assessment_id = get_first_aid_by_cud(cud)
    assessment_name = Assessment.find(assessment_id).name
    # create an autograder
    Autograder.new(assessment_id: assessment_id, autograde_timeout: 180,
                   autograde_image: "autograding_image", release_score: true).save

    it "updates autograder" do
      put :update, params: {course_name: course_name, assessment_name: assessment_name, autograder: {autograde_timeout: 120}}
      expect(Autograder.find_by(assessment_id: assessment_id).autograde_timeout).to eq(120)
    end

    it "redirects to edit" do
      put :update, params: {course_name: course_name, assessment_name: assessment_name, autograder: {autograde_timeout: 120}}
      expect(response).to redirect_to(edit_course_assessment_autograder_path(course_name, assessment_name))
      expect(flash[:success]).to eq("Autograder saved!")
    end

    it "renders with failure" do
      allow_any_instance_of(Autograder).to receive(:save).and_return(false)
      put :update, params: {course_name: course_name, assessment_name: assessment_name, autograder: {autograde_timeout: 120}}
      expect(response).to redirect_to(edit_course_assessment_autograder_path(course_name, assessment_name))
      expect(flash[:error]).to eq("Autograder could not be saved.")
    end
  end
end
