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


  # makeDlist - Creates a string of emails that can be added as b/cc field.
  # @param section The section to email.  nil if we should email the entire
  # class. 
  # @return The filename of the dlist that was created. 
  def makeDlist(cuds)
    #We're going to create the dlist file right quick.
   
    emails = []

    for cud in cuds do 
      emails << "#{cud.user.email}"
    end


    return emails.join(",")
  end

end
