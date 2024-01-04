require "rails_helper"
require_relative("../support/controller_macros")
include ControllerMacros

RSpec.describe "manage submissions user flow", type: :feature do
  describe "click button", js: true do
    context "when user is Instructor" do
      # can't use login_as for features
      let(:user) do
        create_course_with_users
        @instructor_user
      end
      let(:assessment_name) do
        cud = get_first_cud_by_uid(user)
        assessment_id = get_first_aid_by_cud(cud)
        Assessment.find(assessment_id).display_name
      end
      it "allows editing manage session" do
        # Simulates user log in
        visit "/auth/users/sign_in"
        fill_in "user_email",    with: user.email
        fill_in "user_password", with: "testPassword"

        click_on "Sign in"
        click_on "Go to Courses Home"
        click_on "Go to Course Page"
        click_on assessment_name

        click_on "Manage submissions"
        first(:link, "Edit the grading properties of this submission").click
        fill_in("submission_notes", with: "test notes")
        fill_in("submission_tweak_attributes_value", with: "1.0")

        click_on("Update Submission")

        # TODO: check values are okay
        # seems like there's a bug currently because after submitting, instructor
        # gets redirected to their own submission history instead of back to manage submissions
      end
    end
  end
end
