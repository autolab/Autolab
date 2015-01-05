RSpec.describe "home page", :type => :feature do
  it "allows registered user to log in" do
    user = FactoryGirl.create(:user)

    # Simulates user log in
    visit "/auth/users/sign_in"
    fill_in "user_email",    :with => user.email
    fill_in "user_password", :with => user.password 
    click_button "Sign in"

    expect(page).to have_content 'Signed in successfully.'
  end
end

