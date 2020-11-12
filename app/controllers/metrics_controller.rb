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
			instances = WatchlistInstance.get_instances_for_course(course_name)
			render json: instances
		rescue => error
			render :text => 'Not Found', :status => '404'
			return
		end
	end

	action_auth_level :update_watchlist_instances, :instructor
	def update_watchlist_instances
		# This API endpoint retrieves the watchlist instances for a particular course
		# On success, a JSON list of watchlist instances will be returned
		# params required would be the course name
		# each watchlist instance will contain course_user_datum, course_id, risk_condition_id
		# status (new, resolved, contacted), archived or not, and violation info 
		# (a json containing more info pertaining to violation)
		# On error, a 404 error is returned
		
		begin
			course_name = params[:course_name]
		rescue => error
			render :text => "Not Found", :status => '404'
			return
		end

		begin
		update = params[:update]
			instances = WatchlistInstance.get_instances_for_course(course_name)
			instances.each do |instance|
				case update[instance.risk_condition_id]
				when "contact"
					instance.contact_watchlist_instance
				when "resolve"
					instance.resolve_watchlist_instance
				end
			end
		rescue => error
			render :text=> error, :status => '403'
			return
		end

		return :text => "Successfully updated instances", :status=>"200"
	end
end
