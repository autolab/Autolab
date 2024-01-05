class MetricsController < ApplicationController
  action_auth_level :index, :course_assistant
  def index
    course = Course.find_by(name: params[:course_name])
    permission_check

    @course_grace_days = course.grace_days
    @course_assessment_categories = course.assessment_categories
    @num_assessments = course.assessments.count

    course_max = course.assessments.group("category_name").count.max
    @max_consecutive_assessments = if course_max.nil?
                                     0
                                   else
                                     course_max[1]
                                   end

    @allow_ca = course.watchlist_allow_ca
  end

  action_auth_level :get_current_metrics, :course_assistant
  def get_current_metrics
    # This API endpoint aims to retrieve the current/latest risk conditions for a particular course
    # On success, a JSON list of condition objects will be returned
    # The type of each object is specified in a field called "condition_type"
    # Possible types include: no_condition_selected, grace_day_usage,
    #                         grade_drop, no_submission, low_grades
    # Other fields for a risk condition object include:
    #                         parameters, version, created_at,
    #                         updated_at, and course_id
    # In particular, the parameters field includes specific information
    # of the condition corresponding to its type
    # On error, a flash error message will be shown and nil gets returned
    permission_check

    course_name = params[:course_name]
    conditions = RiskCondition.get_current_for_course(course_name)
    render json: conditions, status: :ok
  rescue StandardError => e
    render json: { error: e.message }, status: :not_found
    nil
  end

  action_auth_level :get_watchlist_instances, :course_assistant
  def get_watchlist_instances
    # This API endpoint retrieves the watchlist instances for a particular course
    # On success, a JSON that contains the following will be returned
    #
    # instances: list of watchlist instances will be returned
    # each watchlist instance will contain course_user_datum, course_id, risk_condition_id
    # status (pending, resolved, contacted), archived or not, and violation info
    # (a json containing more info pertaining to violation)
    #
    # risk_conditions: dictionary of risk conditions found in watchlist instances,
    # key being the risk_condition_id each entry contains the condition_type
    #
    # users: dictionary of users found in watchlist instances, key being the course_user_datum_id
    # each entry contains the first name, last name and email
    #
    # params required would be the course name
    # On error, a 404 error is returned
    permission_check

    course_name = params[:course_name]
    instances = WatchlistInstance.get_instances_for_course(course_name)

    course_user_data_ids = instances.map(&:course_user_datum_id)
                                    .reject(&:nil?).uniq

    user_data = User.joins(:course_user_data)
                    .where(course_user_data: { id: course_user_data_ids })
                    .select('users.id as user_id,
								             users.first_name,
									           users.last_name,users.email,
									           course_user_data.id as course_user_datum_id')
                    .as_json

    user_hash = user_data.index_by do |entry|
      entry["course_user_datum_id"]
    end

    risk_condition_ids = instances.map(&:risk_condition_id)
                                  .reject(&:nil?).uniq

    risk_condition_data = RiskCondition.where(id: risk_condition_ids)
                                       .select("id,condition_type").as_json

    risk_hash = risk_condition_data.index_by do |entry|
      entry["id"]
    end

    render json: { risk_conditions: risk_hash, users: user_hash, instances: },
           status: :ok
  rescue StandardError => e
    render json: { error: e.message }, status: :not_found
    nil
  end

  action_auth_level :get_num_pending_instances, :course_assistant
  def get_num_pending_instances
    # This API endpoint retrieves the number of pending watchlist instances for a particular course
    # On success, a JSON containing num_pending will be returned
    # On error, a 404 error is returned
    permission_check

    course_name = params[:course_name]
    number = WatchlistInstance.get_num_pending_instance_for_course(course_name)
    render json: { "num_pending": number }, status: :ok
  rescue StandardError => e
    render json: { error: e.message }, status: :not_found
    nil
  end

  action_auth_level :refresh_watchlist_instances, :course_assistant
  def refresh_watchlist_instances
    # This API endpoint refreshes the watchlist instances for a particular course from scratch
    # Any previously added watchlist instances will be archived
    # Any current watchlist instances whose risk conditions
    # match the latest conditions will be destroyed
    # On success, a JSON list of watchlist instances will be returned
    # params required would be the course name
    # each watchlist instance will contain course_user_datum, course_id, risk_condition_id
    # status (pending, resolved, contacted), archived or not,
    # and violation info
    # Specifically, violation info for each condition category
    # takes on the following form (examples):
    # grace_day_usage: { "Homework 1" => 2, "Homework 3" => 2 }
    # grade_drop: { "Homework" => [{ "Homework 1" => "100/100", "Homework 3" => "80/100"}, ...],
    #               "Lab" => [{"Lab 1" => "10/10", "Lab 3" => "8/10" }] }
    # no_submissions: { "no_submissions_asmt_names" => [ "Homework 1", "Quiz 2", ... ] }
    # low_grades: { "Homework 1" => "70/100", ... }
    # On error, an error json is rendered and status is set to :bad_request
    permission_check

    course_name = params[:course_name]
    new_instances = WatchlistInstance.refresh_instances_for_course(course_name)
    render json: new_instances, status: :ok
  rescue StandardError => e
    render json: { error: e.message }, status: :bad_request
    nil
  end

  action_auth_level :update_current_metrics, :instructor
  def update_current_metrics
    # This API endpoint aims to update current/latest risk conditions for a particular course
    # On success, a JSON list of condition objects that are freshly
    # created out of the request parameters will be returned
    # The request parameters must take on the following format:
    #
    # params[type_a] is nil if instructor does not want
    # to include a risk condition of type_a during update
    # params[type_a] is an object satisfying the parameter
    # requirement for type_a condition
    #
    # e.g. params["grace_day_usage"] should have form
    # { "grace_day_threshold" => 3, "date" => "2020-03-05" }
    # Currently, four types of risk conditions are supported:
    # "grace_day_usage" with parameters "grace_day_threshold", "date"
    # "grade_drop" with parameters "percentage_drop", "consecutive_counts"
    # "no_submissions" with parameter "no_submissions_threshold"
    # "low_grades" with parameters "grade_threshold", "count_threshold"
    # On error, an error json will be rendered

    course_name = params[:course_name]
    params_filtered = new_metrics_params
    params_filtered = if params_filtered.nil?
                        {}
                      else
                        params_filtered.to_h
                      end

    if params_filtered != params[:metric]
      raise "Invalid update parameters for risk conditions!"\
            " Make sure your request body fits the criteria!"
    end

    conditions = RiskCondition.update_current_for_course(course_name, params_filtered)
    render json: conditions, status: :ok
  rescue StandardError => e
    render json: { error: e.message }, status: :bad_request
    nil
  end

  action_auth_level :update_watchlist_instances, :course_assistant
  def update_watchlist_instances
    # This API endpoint updates watchlist instances for a particular course
    # On success, the watchlist instance will be updated appropriately
    # params required would be the course name
    # example json body {"method":"resolve","ids":[1,2,3]}
    # method: contact, resolve
    # ids: [1,2,3...] list of ids to be updated
    permission_check

    begin
      course_name = params[:course_name]
      raise "Course name cannot be blank" if course_name.blank?
    rescue StandardError => e
      render json: { error: e.message }, status: :not_found
      return
    end

    begin
      raise "Method not defined" if params[:method].nil?

      raise "No ids given" if params[:ids].nil?

      case params[:method]
      when "contact"
        WatchlistInstance.contact_many_watchlist_instances(params[:ids])
      when "resolve"
        WatchlistInstance.resolve_many_watchlist_instances(params[:ids])
      when "delete"
        WatchlistInstance.delete_many_watchlist_instances(params[:ids])
      else
        raise "Method #{params[:method]} not allowed"
      end
    rescue StandardError => e
      render json: { error: e.message }, status: :method_not_allowed
      return
    end

    render json: { message: "Successfully updated instances" }, status: :ok
  end

  action_auth_level :get_watchlist_configuration, :course_assistant
  def get_watchlist_configuration
    # This API endpoint aims to retrieve the current/latest category blocklist for a course
    # On success, a JSON list of category names will be returned
    # On error, an error message in JSON will be rendered
    permission_check

    begin
      course_name = params[:course_name]
      raise "Course name cannot be blank" if course_name.blank?

      category_blocklist = WatchlistConfiguration.get_category_blocklist_for_course(course_name)
      allow_ca = @course.watchlist_allow_ca
    rescue StandardError => e
      render json: { error: e.message }, status: :not_found
      return
    end

    render json: { category_blocklist:, allow_ca: }, status: :ok
  end

  action_auth_level :update_watchlist_configuration, :instructor
  def update_watchlist_configuration
    # This API endpoint updates a course's watchlist configuration
    # On success, a JSON object of watchlist configuration will be returned
    # params required include course_name, blocklist and allow_ca
    # blocklist should be a hash in the following form:
    # { "category": ["Lab", "Homework"], "assessment": ["homework1", "homework2"] }
    # allow_ca should be a boolean
    # Note: The assessment names ARE NOT the display names.
    begin
      course_name = params[:course_name]
      raise "Course name cannot be blank" if course_name.blank?
    rescue StandardError => e
      render json: { error: e.message }, status: :not_found
      return
    end

    begin
      # handle nil blocklist in models
      config = WatchlistConfiguration.update_watchlist_configuration_for_course(course_name,
                                                                                params[:blocklist],
                                                                                params[:allow_ca])
    rescue StandardError => e
      render json: { error: e.message }, status: :bad_request
      return
    end

    render json: config, status: :ok
  end

private

  def new_metrics_params
    return if params[:metric].blank?

    params.require(:metric).permit(grace_day_usage: %i[grace_day_threshold date],
                                   grade_drop: %i[
                                     percentage_drop consecutive_counts
                                   ],
                                   no_submissions: [:no_submissions_threshold],
                                   low_grades: %i[
                                     grade_threshold count_threshold
                                   ],
                                   extension_requests: %i[
                                     extension_count
                                   ])
  end

  def permission_check
    return if @cud.instructor || @cud.course_assistant && @course.watchlist_allow_ca

    flash[:error] = "You do not have permission to access the metrics feature."
    redirect_to([@course]) && return
  end
end
