class RegistrationsController < Devise::RegistrationsController
protected

  # After hitting the 'Sign up' page, redirect users here so that they see the
  # confirmation flash message ("check your email...")
  def after_inactive_sign_up_path_for(_resource)
    # /auth/users/sign_in
    new_user_session_path
  end
end
