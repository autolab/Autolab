class RiskCondition < ApplicationRecord
  serialize :parameters, Hash
  enum condition_type: [:no_condition_selected, :grace_day_usage, :grade_drop, :no_submissions, :low_grades]

  has_many :watchlist_instances, dependent: :destroy
  belongs_to :course

  # parameter correspondence:
  # :grace_day_usage => :grace_day_threshold, :date
  # :grade_drop => :percentage_drop, :consecutive_counts
  # :no_submissions => :no_submissions_threshold
  # :low_grades => :grade_threshold, :count_threshold

  def self.create_condition_for_course_with_type(course_id, type, params, version)
  	# parameter check shouldn't surface to user and is for sanity check during development only
    if (type == 1 && (params[:grace_day_threshold].nil? || params[:date].nil? || params.length != 2)) ||
       (type == 2 && (params[:percentage_drop].nil? || params[:consecutive_counts].nil? || params.length != 2)) ||
       (type == 3 && (params[:no_submissions_threshold].nil? || params.length != 1)) ||
       (type == 4 && (params[:grade_threshold].nil? || params[:count_threshold].nil? || params.length != 2))
      raise "Invalid update parameters for risk conditions! Make sure your request body fits the criteria!"
    end

    options = { course_id: course_id, condition_type: type, parameters: params, version: version }
    new_risk_condition = RiskCondition.new(options)
    if not new_risk_condition.save
      raise "Fail to create new risk condition with type #{type} for course #{course_id}"
    end
    return new_risk_condition
  end

  def self.get_current_for_course(course_name)
    conditions = []
    course_id = Course.find_by(name: course_name).id
    max_version = RiskCondition.get_max_version(course_id)
    
    return [] if max_version == 0
    
    conditions_for_course = RiskCondition.where(course_id: course_id, version: max_version)
    condition_types = conditions_for_course.map { |condition| condition.condition_type.to_sym }
    if condition_types.any? { |type| type == :no_condition_selected }
      return []
    else
      return conditions_for_course
    end
  end

  def self.update_current_for_course(course_name, params)
    # The code below assumes params[type] contains a hash of the parameters needed for the type
    # where type is a string corresponding to the four types defined at the top of this file
    course_id = Course.find_by(name: course_name).id
    max_version = RiskCondition.get_max_version(course_id)
    # Is params empty?
    if params.length == 0 and max_version == 0
      # puts "case 1: max_version = 0 (no previous conditons have been set) and instructor doesn't want any at this point"
      return []
    end
    
    previous_conditions = RiskCondition.where(course_id: course_id, version: max_version)
    previous_types = previous_conditions.map { |c| c.condition_type }
    if params.length == 0
      if previous_types.length > 0 and not previous_types.any? { |t| t == "no_condition_selected" }
        # puts "case 2: previous conditions set to something and instructor doesn't want any this time"
        create_condition_for_course_with_type(course_id, 0, {}, max_version + 1)
      # else
      #   puts "case 3: previous conditions set to nothing selected and instructor doesn't want any this time either"
      end
      # indicator row for "currently no conditions selected" that user doesn't need to access
      return []
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
        # puts "case 4: instructor changed conditions this time; previous conditions were either unset, or different from current parameters"
        params.map do |k, v|
          new_condition = create_condition_for_course_with_type(course_id, self.condition_types[k], v, max_version + 1)
          conditions << new_condition
        end
      # else
      #   puts "case 5: previous conditions and current conditions match and no update is needed"
      end
      return conditions
    end
  end

private

  def self.get_max_version(course_id)
    conditions = []
    conditions_for_course = RiskCondition.where(course_id: course_id)
    versions = conditions_for_course.map { |each| each.version }
    max_version = versions.max
    if max_version.nil?
      return 0
    else
      return max_version
    end
  end

end
