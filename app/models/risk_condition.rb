class RiskCondition < ApplicationRecord
  serialize :parameters, Hash
  enum condition_type: [:grace_day_usage, :grade_drop, :no_submissions, :low_grades]

  has_many :watchlist_instances, dependent: :destroy
  belongs_to :course

  # parameter correspondence:
  # :grace_day_usage => :grace_day_threshold, :date
  # :grade_drop => :percentage_drop, :consecutive_counts
  # :no_submissions => :no_submissions_threshold
  # :low_grades => :grade_threshold, :count_threshold

  def self.create_condition_for_course_with_type(course_id, type, params, version)
  	# parameter check shouldn't surface to user and is for sanity check during development only
    if (type == :grace_day_usage && (params[:grace_day_threshold].nil? || params[:date].nil? || params.length != 2)) ||
       (type == :grade_drop && (params[:percentage_drop].nil? || params[:consecutive_counts].nil? || params.length != 2)) ||
       (type == :no_submissions && (params[:no_submissions_threshold].nil? || params.length != 1)) ||
       (type == :low_grades && (params[:grade_threshold].nil? || params[:count_threshold].nil? || params.length != 2))
      raise "Parameters for risk condition does not match type!"
    end

    options = { course_id: course_id, condition_type: type, parameters: params, version: version }
    newRiskCondition = RiskCondition.new(options)
    if not newRiskCondition.save
      raise "Fail to create new risk condition with type #{type} for course #{course_id}"
    end
    return newRiskCondition
  end

  def self.get_current_for_course(course_name)
    conditions = []
    course_id = Course.find_by(name: course_name).id
    max_version = RiskCondition.get_max_version(course_id)
    conditions_for_course = RiskCondition.where(course_id: course_id, :version => max_version)
    # for type in RiskCondition.condition_types do
    #   condition = conditions_for_course.where(condition_type: type[1]).order("version DESC").first
    #   if not condition.nil?
    #     conditions << condition
    #   end
    # end
    # condition_versions = conditions.map { |h| h.version }
    # max_version = condition_versions.max()
    # conditions = conditions.select { |c| c.version == max_version }
    return conditions_for_course
  end

  def self.update_current_for_course(course_name, params)
    # The code below assumes params[type] contains a hash of the parameters needed for the type
    conditions = []
    course_id = Course.find_by(name: course_name).id
    max_version = RiskCondition.get_max_version(course_id)
    for type in RiskCondition.condition_types do
      if params[type[1]]
        new_condition = create_condition_for_course_with_type(course_id, type[1], params[type[1]], max_version + 1)
        conditions << new_condition;
      end
    end
    return conditions
  end

private

  def self.get_version(course_id, type)
    previous = RiskCondition.where(course_id: course_id, condition_type: type).order("version DESC")
    if previous.first
      return previous.first.version + 1
    else
      return 1
    end
  end

  def self.get_max_version(course_id)
    conditions = []
    conditions_for_course = RiskCondition.where(course_id: course_id)
    max_version = 0
    for type in RiskCondition.condition_types do
      condition = conditions_for_course.where(condition_type: type[1]).order("version DESC").first
      if not condition.nil?
        if condition.version > max_version
          max_version = condition.version
        end
      end
    end
    
    return max_version
  end

end
