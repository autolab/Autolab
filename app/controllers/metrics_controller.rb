class MetricsController < ApplicationController
	action_auth_level :index, :instructor
	def index
	end

private
	def get_current_metrics(course_id)
		# returned as a hash, with each type's integer index as a key
		# GRACE_DAY_USAGE = 1 # :grace_day_threshold, :date
		# GRADE_DROP = 2 # :percentage_drop, :consecutive_counts
		# NO_SUBMISSIONS = 3 # :no_submissions_threshold
		# LOW_GRADES = 4 # :grade_threshold, :count_threshold
		return RiskCondition.get_current_for_course(course_id)
	end
end
