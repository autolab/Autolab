require "tempfile"
require "uri"
require "httparty"

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
    expect(page).to have_content "autograded"

    # The tests below have been commented out as it requires Tango to be
    # running and make a callback back to the server
    # However, the active validation for the callback url requires it to
    # be an SSL/TLS url in api_shared_context.rb
    # Therefore this test is not feasible to be run in a test environment
    # which will not have SSL configured and so this test
    # has been disabled. The tests are left
    # here as reference for the future if we do wish to perform such
    # testing again.
    #
    #
    # expect(page).to have_content "Refresh the page to see the results."
    # asmt_page = URI.parse(current_url).request_uri
    #
    # # Verify job status page
    # sleep(15)
    # first("#flash_success a").click
    # expect(page).to have_content "AutoPopulated_labtemplate"
    # expect(page).to have_content "Success: Autodriver returned normally"
    #
    # # Generate random score
    # score = (0...2).map { (0x31 + rand(9)).chr }.join
    #
    # # Send a callback to local endpoint
    # callback_url = first("li", text: "autograde_done").text.split[1]
    # callback_path = URI.parse(callback_url).request_uri
    # tmp_feedback = Tempfile.new("feedback.txt")
    # tmp_feedback << "{\"scores\": {\"autograded\": #{score}}}"
    # tmp_feedback.flush
    # tmp_feedback.close
    # page.driver.post(callback_path,
    #                  file: Rack::Test::UploadedFile.new(tmp_feedback.path,
    #                                                     "application/octet-stream"))
    #
    # # Verify that grade has been populated
    # sleep 5
    # visit asmt_page
    # expect(page).to have_content score
  end
end
