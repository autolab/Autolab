class CourseMailer < ActionMailer::Base
  
  def system_announcement(sender, to, subject, text)
    @text = text

    return mail(
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

    return mail(
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
      to: "autolab-dev@andrew.cmu.edu",
      subject: subject,
      from: @user.email,
      sent_on: Time.now
    )
  end


end
