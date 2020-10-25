class RiskCondition < ApplicationRecord
  serialize :parameters, Hash

  has_many :watchlist_instances, dependent: :destroy
  belongs_to :course

  GRACE_DAY_USAGE = 1 # :grace_day_threshold, :date
  GRADE_DROP = 2 # :percentage_drop, :consecutive_counts
  NO_SUBMISSIONS = 3 # :no_submissions_threshold
  LOW_GRADES = 4 # :grade_threshold, :count_threshold

  def self.create_condition_for_course_with_type(course_id, type, params)
  	# parameter check shouldn't surface to user and is for debug only
    if (type == GRACE_DAY_USAGE && (params[:grace_day_threshold].nil? || params[:date].nil? || params.length != 2)) ||
       (type == GRADE_DROP && (params[:percentage_drop].nil? || params[:consecutive_counts].nil? || params.length != 2)) ||
       (type == NO_SUBMISSIONS && (params[:no_submissions_threshold].nil? || params.length != 1)) ||
       (type == LOW_GRADES && (params[:grade_threshold].nil? || params[:count_threshold].nil? || params.length != 2))
      raise "Parameters for risk condition does not match type!"
    end

    version = RiskCondition.get_version(course_id, type)
    options = { type: type, parameters: params, version: version }
    newRiskCondition = RiskCondition.new(options)
    if not newRiskCondition.save
      raise "Fail to create new risk condition with type #{type} for course #{course_id}"
    end
  end

private

  def self.get_version(course_id, type)
    previous = RiskCondition.where(course_id: course_id, type: type).order("version DESC")
    if previous.first
      return previous.first.version + 1
    else
      return 1
    end
  end

end
