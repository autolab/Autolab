class MetricsController < ApplicationController
	action_auth_level :index, :instructor
	def index
	end

	action_auth_level :get_current_metrics, :instructor
	def get_current_metrics
		# This API endpoint aims to retrieve the current/latest risk conditions for a particular course
		# On success, a JSON list of condition objects will be returned
		# The type of each object is specified in a field called "condition_type"
		# Possible types include: grace_day_usage, grade_drop, no_submission, low_grades
		# Other fields for a risk condition object include parameters, version, created_at, updated_at, and course_id
		# In particular, the parameters field includes specific information of the condition corresponding to its type
		# On error, a flash error message will be shown and nil gets returned
		begin
			course_name = params[:course_name]
			conditions = RiskCondition.get_current_for_course(course_name)
			render json: conditions
		rescue => error
			flash[:error] = error.message
			return
		end
	end
end
