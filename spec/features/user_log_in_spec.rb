require "spec_helper"

describe "authentication homepage" do
  it "allows registered and confirmed user to log in" do
    # Creates a dummy user
    user = User.create!(:email => "user@foo.bar",
                        :first_name => "Test",
                        :last_name => "User",
                        :password => "AutolabProject")
    user.skip_confirmation!
    user.save!

    # Simulates user log in
    visit "/auth/users/sign_in"
    fill_in "user_email",    :with => "user@foo.bar"
    fill_in "user_password", :with => "AutolabProject"
    click_button "Sign in"

    expect(page).to have_content 'Signed in successfully.'
  end
end

