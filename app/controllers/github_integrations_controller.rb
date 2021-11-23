class GithubIntegrationsController < ApplicationController
  skip_before_action :set_course
  skip_before_action :authorize_user_for_course
  skip_before_action :authenticate_for_action
  skip_before_action :update_persistent_announcements
  before_action :set_github_integration

  # This API endpoint retrives the 30 most recently pushed repositories of the user
  # if the user has connected their account to Github
  action_auth_level :get_repositories, :student
  def get_repositories
    return fail_with_reason("User not connected to Github") unless @github_integration
    repositories = @github_integration.repositories
    render json: repositories, status: :ok
  rescue StandardError => e
    render json: { error: e.message }, status: :not_found
    nil
  end

  action_auth_level :get_branches, :student
  def get_branches
    return fail_with_reason("User not connected to Github") unless @github_integration
    return fail_with_reason("Repository not provided") unless params["repository"]
    branches = @github_integration.branches(params["repository"])
    render json: branches, status: :ok
  rescue StandardError => e
    render json: { error: e.message }, status: :not_found
    nil
  end

  private

  def set_github_integration
    gi = current_user.github_integration
    if gi && gi.is_connected
      @github_integration = current_user.github_integration
    end
  end

  def fail_with_reason(reason)
    render json: { error: reason }, status: :not_found
    nil
  end
end
