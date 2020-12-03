class Penalty < ScoreAdjustment
  # penalties should always be positive
  validates_numericality_of :value, greater_than_or_equal_to: 0

  after_save :update_course_grade_watchlist_instances_if_necessary

  SERIALIZABLE = Set.new %w(kind value)
  def serialize
    Utilities.serializable attributes, SERIALIZABLE
  end

  def self.applied_penalty(penalty, score, multiplier)
    superclass.applied_value(penalty, score, multiplier)
  end

  # Penalty updates for course take on the approach of generating new penalty rows
  # Whereas penalty updates for assessments hold onto one single row, only changing the relevant
  # fields of that row
  # So here we only need to worry if penalty owns an assessment
  def update_course_grade_watchlist_instances_if_necessary
  	course_candidate_1 = Course.find_by(late_penalty_id: self.id)
  	course_candidate_2 = Course.find_by(version_penalty_id: self.id)
  	if course_candidate_1.nil? and course_candidate_2.nil?
  		assessment_candidate_1 = Assessment.find_by(late_penalty_id: self.id)
  		assessment_candidate_2 = Assessment.find_by(version_penalty_id: self.id)
  		unless assessment_candidate_1.nil? or assessment_candidate_2.nil?
  			raise "The same penalty adjustment applies to two assessments! Unacceptable!"
  		end
  		if not assessment_candidate_1.nil?
  			assessment = assessment_candidate_1
  		elsif not assessment_candidate_2.nil?
  			assessment = assessment_candidate_2
  		else
  			return
  		end
  		assessment.update_course_grade_watchlist_instances_if_past_end_at
  	end
  end
end
