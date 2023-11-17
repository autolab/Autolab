class PasswordMailer < ActionMailer::Base
  def admin_password_reset(user, password)
    @user = user
    @password = password

    mail(
      subject: "Your new Autolab password",
      to: @user.email,
      sent_on: Time.now
    )
  end
end
