require "rails_helper"
require_relative("../support/controller_macros")
include ControllerMacros

RSpec.describe "manage submissions user flow", type: :feature do
  describe "click button", js: true do
    context "when user is Instructor" do
      # can't use login_as for features
      user_id = User.create!(email: "autolabintructor@foo.bar",
                             first_name: "Test",
                             last_name: "User",
                             password: "AutolabProject")
      user_id.skip_confirmation!
      user_id.save!

      cid = get_first_course
      CourseUserDatum.create!({
                                user: user_id,
                                course: cid,

                                course_number: "AutoPopulated",
                                lecture: "1",
                                section: "A",
                                dropped: false,

                                instructor: true,
                                course_assistant: true,

                                nickname: "instructor"
                              })
      it "allows editing manage session" do
        # Simulates user log in
        visit "/auth/users/sign_in"
        fill_in "user_email",    with: "autolabintructor@foo.bar"
        fill_in "user_password", with: "AutolabProject"

        click_on "Sign in"
        click_on "Go to Courses Home"
        click_on "Go to Course Page"
        click_on "Homework 0"

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
