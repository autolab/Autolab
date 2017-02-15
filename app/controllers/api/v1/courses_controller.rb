class Api::V1::CoursesController < Api::V1::BaseApiController

  def index
    courses_for_user = User.courses_for_user current_user

    if params.has_key?(:state)
    	if params[:state] == "disabled"
    		courses_for_user = courses_for_user.select { |course| course.disabled? }
    	elsif ["completed", "current", "upcoming"].include? params[:state]
    		state = params[:state].to_sym
    		courses_for_user = courses_for_user.select { |course| course.temporal_status == state }
    	else
    		# invalid state
    		raise ApiError.new("Unexpected course state", :bad_request)
    	end
    end

    respond_with courses_for_user
  end

end