class Score < ApplicationRecord
  belongs_to :submission
  belongs_to :problem
  belongs_to :grader, class_name: "CourseUserDatum"

  after_save :invalidate_raw_score
  after_destroy :invalidate_raw_score

  scope :on_latest_submissions, -> { where(submissions: { ignored: false }).joins(submission: :assessment_user_datum) }

  def self.for_course(course_id)
    where(assessments: { course_id: course_id }).joins(submission: :assessment)
  end

  delegate :invalidate_raw_score, to: :submission

  # Verifies that we will only ever have one score per problem per submission
  # This is what allows us to use submission.scores.maximum(:score,:group=>:problem_id) later on
  validates_uniqueness_of(:problem_id, scope: :submission_id)
  validates_presence_of :grader_id

  after_save :log_entry

  def self.find_with_feedback(*args)
    with_exclusive_scope { find(*args) }
  end

  # Requires submission_id, problem_id not null
  def self.find_or_initialize_by_submission_id_and_problem_id(submission_id, problem_id)
    if submission_id.nil? || problem_id.nil?
      raise InvalidScoreException.new, "submission_id and problem_id cannot be empty"
    end
    score = Score.find_by(submission_id: submission_id, problem_id: problem_id)

    if !score
      return Score.new(submission_id: submission_id, problem_id: problem_id)
    else
      return score
    end
  end

  def log_entry
    if grader_id != 0
      setter = grader.user.email
    else
      setter = "Autograder"
    end

    # Some scores don't have submissions, probably if they're deleted ones
    unless submission.nil?
      COURSE_LOGGER.log("Score #{id} UPDATED for " \
      "#{submission.course_user_datum.user.email} set to " \
      "#{score} on #{submission.assessment.name}:#{problem.name} by" \
      " #{setter}")
    end
  end
end
