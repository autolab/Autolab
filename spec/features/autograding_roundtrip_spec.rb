require "tempfile"

RSpec.describe "autograding", type: :feature do
  it "runs through successfully" do
    # Simulates user log in
    visit "/auth/users/sign_in"
    fill_in "user_email", with: "admin@foo.bar"
    fill_in "user_password", with: "adminfoobar"
    click_button "Sign in"
    expect(page).to have_content "Signed in successfully."

    # Goes into assessment submission page
    click_link "AutoPopulated (SEM)"
    click_link "Lab Template"

    # Submit adder file
    tmp_file = Tempfile.new("adder.py")
    tmp_file << "def adder(x,y):\n\treturn x+y"
    tmp_file.flush
    tmp_file.close
    attach_file("submission_file", tmp_file.path)
    click_button "fake-submit"
    expect(page).to have_content "Refresh the page to see the results."

    # Verify job status page
    sleep(15)
    first("#flash_success a").click
    expect(page).to have_content "AutoPopulated_labtemplate"
    expect(page).to have_content "Success: Autodriver returned normally"
  end
end
