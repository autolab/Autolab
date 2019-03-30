module HandinHelper
  def remainingSubmissionsMsg(submissions, assessment)
    numSubmissions = submissions.size
    maxSubmit = (assessment.max_submissions || -1)
    versionThresh = (assessment.effective_version_threshold || -1)
    if maxSubmit == -1 and versionThresh == -1
      return "(unlimited submissions left)"
    elsif maxSubmit != -1 and versionThresh == -1
      return "(#{[maxSubmit - numSubmissions, 0].max} submissions left)"
    elsif versionThresh != -1 and maxSubmit == -1
      return "(#{[versionThresh - numSubmissions, 0].max} unpenalized submissions left)"
    else
      return "(#{[versionThresh - numSubmissions, 0].max} unpenalized, #{[maxSubmit - numSubmissions, 0].max} total submissions left)"
    end
  end
end