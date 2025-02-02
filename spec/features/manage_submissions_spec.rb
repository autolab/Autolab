require "rails_helper"
require_relative("../support/controller_macros")
require_relative("../controllers/controllers_shared_context")
include ControllerMacros

RSpec.describe "manage submissions user flow", type: :feature do
  describe "click button", js: true do
    include_context "controllers shared context"
    context "when user is Instructor" do
      # can't use login_as for features
      let(:user) do
        @instructor_user
      end
      let(:assessment_name) do
        @assessment.display_name
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

        # TODO: check values are okay
        # Check user flow for adding tweaks is okay
      end
    end
  end
end
