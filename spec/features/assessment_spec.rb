require "rails_helper"
require_relative("../support/controller_macros")
require_relative("../controllers/controllers_shared_context")
include ControllerMacros

RSpec.describe "Instructor can create new assessment", type: :feature do
  describe "assessment creation", js: true do
    include_context "controllers shared context"
    context "when user is Instructor" do
      # can't use login_as for features
      let(:user) do
        @instructor_user
      end
      let(:existing_asmt_name) do
        @assessment.display_name
      end
      let(:student) do
        @students.first
      end
      let(:problem) do
        Problem.where(assessment_id: @assessment.id).first
      end
      let(:submission) do
        Submission.where(course_user_datum_id: get_first_cud_by_uid(@students.first.id)).first
      end
      let(:assessment_display_name) do
        "Test Capybara Lab"
      end
      let(:assessment_name) do
        "Test"
      end
      let(:category_name) do
        "test lab"
      end
      let(:bad_handout_name) do
        "handout.pdf"
      end
      let(:good_handout_name) do
        "https://autolabproject.com/"
      end
      let(:comment) do
        "comment1"
      end
      let(:score_adjust) do
        -10
      end
      it "creates new assessment and edits fields" do
        # Simulates user log in
        visit "/auth/users/sign_in"
        fill_in "user_email",    with: user.email
        fill_in "user_password", with: "testPassword"

        click_on "Sign in"
        click_on "Go to Courses Home"
        click_on "Go to Course Page"

        # create assessment from scratch
        click_on "Install Assessment"
        click_on "Create New Assessment"
        fill_in("assessment_display_name", with: assessment_display_name)
        fill_in("new_category", with: category_name)
        click_on "Create assessment"

        # check assessment created correctly
        expect(find('#flash_success')).to have_content "Successfully installed #{assessment_name}."
        click_on "Edit assessment"
        expect(page).to have_field('Name', with: assessment_name, disabled: true)
        expect(page).to have_field('Display name', with: assessment_display_name)
        expect(page).to have_css(".selected", visible: false, text: category_name)

        # modify the handout field, check validation
        fill_in("Handout", with: bad_handout_name)
        click_on "Save"
        expect(find('#flash_error')).to(
          have_content("Handout must be a URL or a file in the assessment folder")
        )
        expect(page).not_to have_field('Handout', with: bad_handout_name)

        fill_in("Handout", with: good_handout_name)
        click_on "Save"
        expect(find('#flash_success')).to have_content "Assessment configuration updated!"
        expect(page).to have_field('Handout', with: good_handout_name)

        click_on "Penalties"
        expect(page).to have_field('Max submissions', with: "Unlimited submissions", disabled: true)
        expect(page).to have_field('Max grace days', with: "0", disabled: false)
        expect(page).to have_field('Version threshold', with: "Course default", disabled: true)
        # for some reason has a hard time finding late penalty and version penalty

        click_on "Advanced"
        expect(page).to have_field('Group size', with: "1", disabled: false)
      end

      it "adds annotation to student submission" do
        visit "/auth/users/sign_in"
        fill_in "user_email",    with: user.email
        fill_in "user_password", with: "testPassword"

        click_on "Sign in"
        click_on "Go to Courses Home"
        click_on "Go to Course Page"
        click_on existing_asmt_name
        click_on "View Gradesheet"

        # click on student's submission
        td = page.find(:css, 'td.id', text: student.email)
        tr = td.find(:xpath, './parent::tr')
        within tr do
          click_on "View Source"
        end
        expect(page).to have_content student.email

        # find the score of first problem, find that it matches backend
        problem_name = page.find(:css, 'div.problem_name', text: /#{problem.name}:/i)
        problem_score = problem_name.find(:xpath, './following-sibling::div')
        old_score = submission.scores.first.score
        within problem_score do
          test = problem_score.find(:css, 'b.student_score')
          expect(test).to have_content old_score
        end

        # add an annotation with score adjustment
        find(:css, "div#line-0.code-line").hover
        find(:css, "button.add-button").click
        fill_in("Comment", with: comment)
        fill_in("Score", with: score_adjust)
        click_on "Add annotation"

        # verify that score was changed
        problem_name = page.find(:css, 'div.problem_name', text: /#{problem.name}:/i)
        problem_score = problem_name.find(:xpath, './following-sibling::div')
        within problem_score do
          test = problem_score.find(:css, 'b.student_score')
          expect(test).to have_content(old_score + score_adjust)
        end
        expect(page).to have_css('div.annotation-badge', text: score_adjust)
      end
    end
  end
end
