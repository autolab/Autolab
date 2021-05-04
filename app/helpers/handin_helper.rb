# frozen_string_literal: true

module HandinHelper
  def remainingSubmissionsMsg(submissions, assessment)
    numSubmissions = submissions.size
    maxSubmit = (assessment.max_submissions || -1)
    versionThresh = (assessment.effective_version_threshold || -1)
    if (maxSubmit == -1) && (versionThresh == -1)
      "(unlimited submissions left)"
    elsif (maxSubmit != -1) && (versionThresh == -1)
      "(#{[maxSubmit - numSubmissions, 0].max} submissions left)"
    elsif (versionThresh != -1) && (maxSubmit == -1)
      "(#{[versionThresh - numSubmissions, 0].max} unpenalized submissions left)"
    else
      "(#{[versionThresh - numSubmissions,
           0].max} unpenalized, #{[maxSubmit - numSubmissions, 0].max} total submissions left)"
    end
  end
end
