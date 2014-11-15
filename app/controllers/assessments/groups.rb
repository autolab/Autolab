module AssessmentGroups 
  
  def groupsListOptions
    @list["group"] = "Check group"
    @list_title["group"] = "Request a group or view your current group"
  end

  # called after a submission is handed in
  def groupsAfterHandin(submission)
    return partnersAfterAutograde(submission)
  end

  # called after a submission is autograded, but also after its been handed in (WTF?)
  def groupsAfterAutograde(submission)
    partner_cud = getPartner(submission.course_user_datum)
    if partner_cud then

      pSubmission = Submission.create(:assessment_id=>@assessment.id,
                                      :course_user_datum_id=>partner_cud.id,
                                      :submitter_ip => request.remote_ip)

      path = File.join(Rails.root, "courses",
                       submission.course_user_datum.course.name,
                       submission.assessment.name,
                       submission.assessment.handin_directory,
                       submission.filename)

      pathMirror = File.join(Rails.root, "tmp", submission.filename)
      `cp #{path} #{pathMirror}`
      sub = { }
      sub["tar"] = pathMirror
      pSubmission.saveFile(sub)
      
      pSubmission.save

      return pSubmission
    end
  end

end 
