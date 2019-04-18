RSpec.describe "home page", type: :feature do
  it "allows registered user to log in" do
    user = FactoryBot.create(:user)

    # Simulates user log in
    visit "/auth/users/sign_in"
    fill_in "user_email",    with: user.email
    fill_in "user_password", with: user.password

    user = User.create!(email: "user@foo.bar",
                        first_name: "Test",
                        last_name: "User",
                        password: "AutolabProject")
    user.skip_confirmation!
    user.save!

    # Simulates user log in
    visit "/auth/users/sign_in"
    fill_in "user_email",    with: "user@foo.bar"
    fill_in "user_password", with: "AutolabProject"

    click_button "Sign in"

    expect(page).to have_content "Signed in successfully."
  end
end
