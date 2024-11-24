class RiskCondition < ApplicationRecord
  serialize :parameters, Hash
  enum condition_type: { no_condition_selected: 0, grace_day_usage: 1, grade_drop: 2,
                         no_submissions: 3, low_grades: 4, extension_requests: 5 }

  has_many :watchlist_instances, dependent: :destroy
  belongs_to :course

  # parameter correspondence:
  # :grace_day_usage => :grace_day_threshold, :date
  # :grade_drop => :percentage_drop, :consecutive_counts
  # :no_submissions => :no_submissions_threshold
  # :low_grades => :grade_threshold, :count_threshold
  # :extension_requests => :extension_count

  def self.create_condition_for_course_with_type(course_id, type, params, version)
    # parameter check shouldn't surface to user and is for sanity check during development only
    if (type == 1 && (params[:grace_day_threshold].nil? ||
                      params[:date].nil? || params.length != 2)) ||
       (type == 2 && (params[:percentage_drop].nil? ||
                      params[:consecutive_counts].nil? || params.length != 2)) ||
       (type == 3 && (params[:no_submissions_threshold].nil? || params.length != 1)) ||
       (type == 4 && (params[:grade_threshold].nil? ||
                      params[:count_threshold].nil? || params.length != 2)) ||
       (type == 5 && (params[:extension_count].nil? || params.length != 1))
      raise "Invalid update parameters for risk conditions! "\
            "Make sure your request body fits the criteria!"
    end

    options = { course_id:, condition_type: type, parameters: params.to_hash,
                version: }
    new_risk_condition = RiskCondition.new(options)
    unless new_risk_condition.save
      raise "Fail to create new risk condition with type #{type} for course #{course_id}"
    end

    new_risk_condition
  end

  def self.get_current_for_course(course_name)
    course_id = Course.find_by(name: course_name).id
    max_version = RiskCondition.get_max_version(course_id)

    return [] if max_version == 0

    conditions_for_course = RiskCondition.where(course_id:, version: max_version)
    condition_types = conditions_for_course.map { |condition| condition.condition_type.to_sym }
    if condition_types.any? { |type| type == :no_condition_selected }
      []
    else
      conditions_for_course
    end
  end

  def self.update_current_for_course(course_name, params)
    # The code below assumes params[type] contains a hash of the parameters needed for the type
    # where type is a string corresponding to the four types defined at the top of this file
    course_id = Course.find_by(name: course_name).id
    max_version = RiskCondition.get_max_version(course_id)
    # Is params empty?
    if params.empty? && (max_version == 0)
      # puts "case 1: max_version = 0 (no previous conditions have been set)
      # and instructor doesn't want any at this point"
      WatchlistInstance.refresh_instances_for_course(course_name, true)
      return []
    end

    previous_conditions = RiskCondition.where(course_id:, version: max_version)
    previous_types = previous_conditions.map(&:condition_type)
    if params.empty?
      if !previous_types.empty? && previous_types.none? { |t| t == "no_condition_selected" }
        # puts "case 2: previous conditions set to something
        # and instructor doesn't want any this time"
        ActiveRecord::Base.transaction do
          create_condition_for_course_with_type(course_id, 0, {}, max_version + 1)
        end
        # else
        #   puts "case 3: previous conditions set to nothing selected and
        #   instructor doesn't want any this time either"
      end
      # indicator row for "currently no conditions selected" that user doesn't need to access
      WatchlistInstance.refresh_instances_for_course(course_name, true)
      []
    else
      conditions = []
      no_change = true
      if params.length == previous_types.length
        previous_conditions.map do |c|
          unless params[c.condition_type] == c.parameters
            no_change = false
            break
          end
        end
      else
        no_change = false
      end

      unless no_change
        # puts "case 4: instructor changed conditions this time;
        # previous conditions were either unset, or different from current parameters"
        ActiveRecord::Base.transaction do
          params.map do |k, v|
            new_condition = create_condition_for_course_with_type(course_id,
                                                                  condition_types[k],
                                                                  v,
                                                                  max_version + 1)
            conditions << new_condition
          end
        end
        # else
        #   puts "case 5: previous conditions and current conditions match and no update is needed"
      end
      WatchlistInstance.refresh_instances_for_course(course_name, true)
      conditions
    end
  end

  def self.get_grade_drop_condition_for_course(course_name)
    current_conditions = get_current_for_course(course_name)
    return nil if current_conditions.count == 0

    # Check for whether there exists one of type :grade_drop
    grade_drop_condition = current_conditions.select { |c| c.condition_type.to_sym == :grade_drop }
    return nil if grade_drop_condition.count != 1

    grade_drop_condition = grade_drop_condition[0]
    [grade_drop_condition.id,
     grade_drop_condition.parameters[:percentage_drop].to_f,
     grade_drop_condition.parameters[:consecutive_counts].to_i]
  end

  def self.get_low_grades_condition_for_course(course_name)
    current_conditions = get_current_for_course(course_name)
    return nil if current_conditions.count == 0

    # Check for whether there exists one of type :low_grades
    low_grades_condition = current_conditions.select { |c| c.condition_type.to_sym == :low_grades }
    return nil if low_grades_condition.count != 1

    low_grades_condition = low_grades_condition[0]
    [low_grades_condition.id,
     low_grades_condition.parameters[:grade_threshold].to_f,
     low_grades_condition.parameters[:count_threshold].to_i]
  end

  # return nil if course doesn't have any current gdu condition
  # return condition_id, grace_day_threshold, date otherwise
  def self.get_gdu_condition_for_course(course_name)
    current_conditions = get_current_for_course(course_name)
    return nil if current_conditions.count == 0

    # Check for whether there exists one of type :grace_day_usage
    grace_day_usage_condition = current_conditions.select do |c|
      c.condition_type.to_sym == :grace_day_usage
    end
    return nil if grace_day_usage_condition.count != 1

    grace_day_usage_condition = grace_day_usage_condition[0]
    [grace_day_usage_condition.id,
     grace_day_usage_condition.parameters[:grace_day_threshold].to_i,
     grace_day_usage_condition.parameters[:date]]
  end

  def self.get_no_submissions_condition_for_course(course_name)
    current_conditions = get_current_for_course(course_name)
    return nil if current_conditions.count == 0

    # Check for whether there exists one of type :no_submissions
    no_submissions_condition = current_conditions.select do |c|
      c.condition_type.to_sym == :no_submissions
    end
    return nil if no_submissions_condition.count != 1

    no_submissions_condition = no_submissions_condition[0]
    [no_submissions_condition.id,
     no_submissions_condition.parameters[:no_submissions_threshold].to_i]
  end

  def self.get_max_version(course_id)
    conditions_for_course = RiskCondition.where(course_id:)
    versions = conditions_for_course.map(&:version)
    max_version = versions.max
    if max_version.nil?
      0
    else
      max_version
    end
  end
end
