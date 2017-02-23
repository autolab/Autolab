class Api::V1::SubmissionsController < Api::V1::BaseApiController

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

end