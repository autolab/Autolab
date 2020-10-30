class MetricsController < ApplicationController
	action_auth_level :index, :instructor
	def index
	end

	def get_current_metrics
		# This API endpoint aims to retrieve the current/latest risk conditions for a particular course
		# User is expected to include in the parameters the course's ID with :id being the key
		# On success, a JSON list of condition objects will be returned
		# The type of each object is specified in a field called "condition_type"
		# Possible types include: GRACE_DAY_USAGE, GRADE_DROP, NO_SUBMISSIONS, LOW_GRADES
		# Other fields for the risk condition object include: parameters, version, created_at, updated_at, and course_id
		# On error, a flash error message will be shown and nothing gets returned (i.e. nil gets returned)
		begin
			course_id = params[:id]
			conditions = RiskCondition.get_current_for_course(course_id)
			render json: conditions
		rescue => error
			flash[:error] = error.message
			return
		end
	end
end
