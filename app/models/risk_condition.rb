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
    # where type is the actual enumeration number
    # params should also be stripped off of the course_name key for ease of process

    course_id = Course.find_by(name: course_name).id
    max_version = RiskCondition.get_max_version(course_id)
    # Is params empty?
    if params.length == 0 and max_version == 0
      puts "case 1: max_version = 0 (no previous conditons have been set) and instructor doesn't want any at this point"
      return []
    elsif max_version > 0
      previous_conditions = RiskCondition.where(course_id: course_id, version: max_version)
      previous_types = previous_conditions.map { |c| c.condition_type.to_sym }
      if params.length == 0
        unless previous_types.any? { |t| t == :no_condition_selected }
          puts "case 2: previous conditions set to something and instructor doesn't want any this time"
          create_condition_for_course_with_type(course_id, 0, {}, max_version + 1)
        else
          puts "case 3: previous conditions set to nothing selected and instructor doesn't want any this time either"
        end
        # indicator row for "currently no conditions selected" that user doesn't need to access
        return []
      else
        conditions = []
        no_change = true
        condition_types = self.condition_types
        if params.length == previous_types.length
          previous_conditions.map do |c|
            type_num = condition_types[c.condition_type]
            unless params[type_num] == c.parameters
              no_change = false
            end
          end
        else
          no_change = false
        end

        unless no_change
          puts "case 4: instructor changed conditions this time; previous conditions were either unset, or different from current parameters"
          params.map do |k, v|
            new_condition = create_condition_for_course_with_type(course_id, k, v, max_version + 1)
            conditions << new_condition
          end
        else
          puts "case 5: previous conditions and current conditions match and no update is needed"
        end
        return conditions
      end
    else
      puts "case 6: previous conditions were not set (i.e. max_version == 0) and instructor wants to set it to something"
      conditions = []
      params.map do |k, v|
        new_condition = create_condition_for_course_with_type(course_id, k, v, max_version + 1)
        conditions << new_condition
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
