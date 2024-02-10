# controls the page that allows users to grant api access to clients
# that use device flow
class DeviceFlowActivationController < ApplicationController
  skip_before_action :set_course
  skip_before_action :authorize_user_for_course
  skip_before_action :authenticate_for_action
  skip_before_action :update_persistent_announcements
  before_action :set_users_list_breadcrumb
  before_action :set_user_breadcrumb, only: %i[index]

  def index; end

  # target for the form on the index page
  def resolve
    unless params.key?(:user_code)
      flash[:error] = "User code missing. Please enter user code."
      redirect_to(action: :index) && return
    end

    req = OauthDeviceFlowRequest.find_by(user_code: params[:user_code])
    if req.nil?
      flash[:error] = "Invalid user code."
      redirect_to(action: :index) && return
    end

    # update user_code to a new random string as identifier for after
    # authorization
    new_code = req.upgrade_user_code

    app = Doorkeeper::Application.find(req.application_id)

    redirect_to oauth_authorization_path(client_id: app.uid,
                                         response_type: "code",
                                         scope: req.scopes,
                                         redirect_uri: device_flow_auth_cb_url,
                                         state: new_code)
  end

  # called by the authorization service
  def authorization_callback
    req = OauthDeviceFlowRequest.find_by(user_code: params[:state])

    if req.nil?
      flash[:error] = "Invalid request"
      redirect_to(action: :index) && return
    end

    if params.key?(:error)
      # encountered error
      req.deny_request(current_user.id)
      flash[:error] = "Access denied by user"
      redirect_to(action: :index) && return
    end

    # no error, store access_code
    req.grant_request(current_user.id, params[:code])
    flash[:success] = "Access granted"
    redirect_to(action: :index) && return
  end

private

  def set_user_breadcrumb
    return if current_user.nil?

    @breadcrumbs << (view_context.link_to current_user.display_name, user_path(current_user))
  end
end
