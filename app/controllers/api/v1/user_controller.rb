class Api::V1::UserController < Api::V1::BaseApiController
  
  before_action -> {require_privilege :user_info}

  skip_before_action :set_course
  skip_before_action :authorize_user_for_course
  
  # endpoint for obtaining current user info
  def show
    respond_with current_user, only: [:first_name, :last_name, :email, :school, :major, :year]
  end

end