class Api::V1::SubmissionsController < Api::V1::BaseApiController

  before_action -> {require_privilege :user_scores}

  before_action :set_assessment

  # endpoint for obtaining all submissions of the current user (student's view).
  # If a score is not released, it is not returned, regardless of user authorization.
  def index
    submissions = @assessment.submissions.where(course_user_datum_id: @cud).order("version DESC")
    
    problems = {}
    @assessment.problems.each do |prob|
      problems[prob.id] = prob.name
    end

    results = []
    submissions.each do |sbm|
      scores = {}
      sbm.scores.each do |scr|
        scores[problems[scr.problem_id]] = scr.released ? scr.score : "unreleased"
      end

      results << {:version => sbm.version,
                  :filename => sbm.filename,
                  :created_at => sbm.created_at,
                  :scores => scores}
    end

    respond_with results
  end

  # endpoint for obtaining feedback of a particular submission.
  def feedback
    # param check
    if !params.has_key?(:problem)
      raise ApiError.new("Required parameter 'problem' not found", :bad_request)
    end
    problem = @assessment.problems.find_by(name: params[:problem])
    raise ApiError.new("Problem named #{params[:problem]} does not exist for #{@assessment.name}", :not_found) unless problem

    vers = params[:submission_version]
    submission = @assessment.submissions.find_by(course_user_datum_id: @cud, version: vers)
    raise ApiError.new("Submission version #{vers} does not exist for #{@assessment.name}", :not_found) unless submission

    # Looks weird, but currently feedbacks are the same for each problem, so we disregard the problem key and just return the first problem with feedback
    score = submission.scores.where.not(feedback: nil).first
    raise ApiError.new("Score for #{params[:problem]} of submission version #{vers} of #{@assessment.name} does not exist", :not_found) unless score

    results = {:feedback => score.feedback}
    respond_with results
  end

end