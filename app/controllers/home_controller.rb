##
# The Home Controller houses (ha) any action that's available to the general public.
#
class HomeController < ApplicationController
  skip_before_action :authenticate_user!
  skip_before_action :set_course
  skip_before_action :authorize_user_for_course
  skip_before_action :authenticate_for_action
  skip_before_action :update_persistent_announcements

  def developer_login
    return unless request.post?

    user = User.find_by(email: params[:email])
    if user
      sign_in :user, user
      flash[:success] = "Signed in as #{user.display_name}"
      redirect_to(root_path)
    else
      flash[:error] = "User with Email: '#{params[:email]}' doesn't exist"
      redirect_to home_developer_login_path
    end
  end

  def contact
    # --- empty ---
    # This route just renders the home#contact page, nothing special
  end

  def error_404; end

  def error_500; end
end
