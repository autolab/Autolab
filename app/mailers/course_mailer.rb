class CourseMailer < ActionMailer::Base
  def system_announcement(sender, to, subject, text)
    @text = text

    mail(
      subject: subject,
      from: sender,
      bcc: to,
      sent_on: Time.now
    )
  end

  def course_announcement(sender, to, subject, text, cud, course)
    @cud = cud
    @course = course
    @text = text

    mail(
      subject: subject,
      from: sender,
      bcc: to,
      sent_on: Time.now
    )
  end

  def bug_report(subject, text, user, course)
    @user = user
    @course = course
    @text = text

    mail(
      to: Rails.configuration.school['tech_email'],
      subject: subject,
      from: @user.email,
      sent_on: Time.now
    )
  end

  def test_email(sender, to, smtp_settings)
    mail(
      subject: 'Autolab Test Email',
      from: sender,
      to: to,
      sent_on: Time.now,
      delivery_method_options: smtp_settings
    )
  end
end
