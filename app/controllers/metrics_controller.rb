class MetricsController < ApplicationController
	action_auth_level :index, :instructor
	def index
	end

	def get_current_metrics(course_id)
		# GRACE_DAY_USAGE = 1 # :grace_day_threshold, :date
		# GRADE_DROP = 2 # :percentage_drop, :consecutive_counts
		# NO_SUBMISSIONS = 3 # :no_submissions_threshold
		# LOW_GRADES = 4 # :grade_threshold, :count_threshold
		begin
			conditions = RiskCondition.get_current_for_course(course_id)
			conditions_json_string = conditions.to_json
			conditions_json = JSON.parse(conditions_json_string)
			conditions_json.map! { |c| c["condition_type"] = type_string_of_enum(c["condition_type"]); c }
			render json: conditions_json
		rescue => error
			return error.message
		end
	end

private
	def type_string_of_enum(t)
		if t == 1
			return "GRACE_DAY_USAGE"
		elsif t == 2
			return "GRADE_DROP"
		elsif t == 3
			return "NO_SUBMISSIONS"
		elsif t == 4
			return "LOW_GRADES"
		else
			raise "Invalid condition type!"
		end
	end
end
