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
			render json: {error:error.message}, status: :not_found
			return
		end
	end

	action_auth_level :update_watchlist_instances, :instructor
	def update_watchlist_instances
		# This API endpoint updates watchlist instances for a particular course
		# On success, the watchlist instance will be updated appropriately
		# params required would be the course name
		# example json body {"method":"resolve","ids":[1,2,3]}
		# method: update, resolve
		# ids: [1,2,3...] list of ids to be updated
		
		begin
			course_name = params[:course_name]
		rescue => error
			render json:  {error:"Course Not Found"}, :status => :not_found
			return
		end
		
		begin
			if params[:method].nil?
				raise "Method not defined"
			end

			if params[:ids].nil?
				raise "No ids given"
			end

			case params[:method]
			when "contact"
				WatchlistInstance.contact_many_watchlist_instances(params[:ids])
			when "resolve"
				WatchlistInstance.resolve_many_watchlist_instances(params[:ids])
			else
				raise "Method #{params[:method]} not allowed"  
			end
		rescue => error
			render json: {error:error.message}, status: :method_not_allowed
			return
		end

		render json: {message:"Successfully updated instances"}, :status => :ok
	end
end
