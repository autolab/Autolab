class Api::V1::CoursesController < Api::V1::BaseApiController

  def index
    courses_for_user = User.courses_for_user current_user

    respond_with courses_for_user
  end

end