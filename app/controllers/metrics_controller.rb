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
			render :text => 'Not Found', :status => '404'
			return
		end
	end

	action_auth_level :get_watchlist_instances, :instructor
	def get_watchlist_instances
		# This API endpoint retrieves the watchlist instances for a particular course
		# On success, a JSON list of watchlist instances will be returned
		# params required would be the course name
		# each watchlist instance will contain course_user_datum, course_id, risk_condition_id
		# status (new, resolved, contacted), archived or not, and violation info 
		# (a json containing more info pertaining to violation)
		# On error, a 404 error is returned
		begin
			course_name = params[:course_name]
			conditions = WatchlistInstance.get_instances_for_course(course_name)
			render json: conditions
		rescue => error
			render :text => 'Not Found', :status => '404'
			return
		end
	end

	action_auth_level :update_current_metrics, :instructor
	def update_current_metrics
		# This API endpoint aims to update current/latest risk conditions for a particular course
		# On success, a JSON list of condition objects that are freshly created out of the request parameters will be returned
		# The request parameters must take on the following format:
		# params[type_a] is nil if instructor does not want to include a risk condition of type_a during update
		# params[type_a] is an object satisfying the parameter requirement for type_a condition
		# e.g. params["grace_day_usage"] should have form { "grace_day_threshold" => 3, "date" => "2020-03-05" }
		# Currently, four types of risk conditions are supported:
		# "grace_day_usage" with parameters "grace_day_threshold", "date"
		# "grade_drop" with parameters "percentage_drop", "consecutive_counts"
		# "no_submissions" with parameter "no_submissions_threshold"
		# "low_grades" with parameters "grade_threshold", "count_threshold"
		# On error, a flash error message will be rendered and nil gets returned
		begin
			course_name = params[:course_name]
			params_filtered = new_metrics_params
			if params_filtered.nil?
				params_filtered = {}
			else
				params_filtered = params_filtered.to_h
			end
			if params_filtered != params[:metric]
				raise "Invalid update parameters for risk conditions! Make sure your request body fits the criteria!"
			end
			conditions = RiskCondition.update_current_for_course(course_name, params_filtered)
			render json: conditions
		rescue => error
			render json: { error: error.message }, status: :bad_request
			return
		end
	end

private
	
	def new_metrics_params
		return params.require(:metric).permit(:grace_day_usage => [:grace_day_threshold, :date],
											  :grade_drop => [:percentage_drop, :consecutive_counts],
											  :no_submissions => [:no_submissions_threshold],
											  :low_grades => [:grade_threshold, :count_threshold]) if params[:metric].present?
	end
end
