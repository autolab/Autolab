class Api::V1::ScoresController < Api::V1::BaseApiController

  before_action -> { require_privilege :instructor_all }
  before_action :set_assessment
  before_action :current_user, only: [:update_latest]

  def index
    submissions = @assessment.submissions.where(assessment_id: @assessment.id)

    scores = {}
    cud_to_user = {}
    submissions.each do |submission|
      cud = submission.course_user_datum_id
      unless cud_to_user.key?(cud)
        cud_to_user[cud] = User.find(CourseUserDatum.find(cud).user_id)
      end
      user = cud_to_user[cud]

      raw_submission_scores = Score.where(submission_id: submission.id)
      user_scores = scores.fetch(user.email, {})
      user_scores[submission.version] = problem_name_to_score(raw_submission_scores)

      scores[user.email] = user_scores
    end

    respond_with scores
  end

  def show
    cud = get_cud params
    submissions = @assessment.submissions.where(
      assessment_id: @assessment.id,
      course_user_datum_id: cud.id
    )

    scores = {}
    submissions.each do |submission|
      raw_submission_scores = Score.where(submission_id: submission.id)
      scores[submission.version] = problem_name_to_score(raw_submission_scores)
    end

    respond_with scores
  end

  def update_latest
    require_params([:problems])

    cud = get_cud params
    aud = AssessmentUserDatum.find_by(assessment_id: @assessment.id, course_user_datum_id: cud.id)

    cuds = []
    update_group_scores = params.key?(:update_group_scores) &&
                          ActiveModel::Type::Boolean.new.cast(params[:update_group_scores].downcase)

    if aud.group_id.nil? || !update_group_scores
      cuds.append(cud.id)
    else
      auds = AssessmentUserDatum.where(assessment_id: @assessment.id, group_id: aud.group_id)
      auds.each do |aud|
        cuds.append(aud.course_user_datum_id)
      end
    end

    scores = {}
    problem_params = JSON.parse(params[:problems])

    Score.transaction do
      cuds.each do |cud_id|
        submission = @assessment.submissions.where(
          assessment_id: @assessment.id,
          course_user_datum_id: cud_id
        ).order(version: :desc).first

        user_scores = {}
        problem_id_to_name = @assessment.problem_id_to_name
        problem_name_to_id = problem_id_to_name.invert

        # Update scores for problems in problem_params
        problem_params.each do |problem_name, updated_score|
          unless problem_name_to_id.include? problem_name
            raise ApiError.new("Problem '#{problem_name}' not found in this assessment", :bad_request)
          end

          score = Score.find_or_initialize_by_submission_id_and_problem_id(
            submission.id, problem_name_to_id[problem_name]
          )
          score.score = updated_score
          score.grader_id = @current_user.id
          unless score.save
            raise ApiError.new("Unable to update #{problem_name} score", :internal_server_error)
          end

          user_scores[problem_name] = updated_score
        end

        # Get the score for non-updated problems
        submission.scores.each do |score|
          problem_name = problem_id_to_name[score.problem_id]
          next if user_scores.include? problem_name

          user_scores[problem_name] = score.score
        end
        scores[user_from_cud(cud_id).email] = user_scores
      end
    end

    render json: scores.as_json, status: :ok
  end

private

  def user_from_cud(cud_id)
    cud = CourseUserDatum.find_by(id: cud_id)
    User.find_by(id: cud.user_id)
  end

  def get_cud(params)
    user = User.find_by email: params[:email]
    if user.nil?
      raise ApiError.new("User with email #{params[:email]} not found in course.", :bad_request)
    end

    cud = CourseUserDatum.find_by(user_id: user.id, course_id: @assessment.course_id)
    if cud.nil?
      raise ApiError.new("User with email #{params[:email]} not found in course.", :bad_request)
    end

    cud
  end

  def problem_name_to_score(raw_scores)
    problem_id_to_name = @assessment.problem_id_to_name
    scores = {}
    raw_scores.each do |score|
      scores[problem_id_to_name[score.problem_id]] = score.score
    end

    scores
  end
end
