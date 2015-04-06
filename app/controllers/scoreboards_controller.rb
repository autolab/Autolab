##
# Each Assessment can have a scoreboard, which is modified with this controller
#
class ScoreboardsController < ApplicationController
  before_action :set_assessment
  before_action :set_assessment_breadcrumb, only: [:edit]
  before_action :set_scoreboard, except: [:create]

  action_auth_level :create, :instructor
  def create
    @scoreboard = Scoreboard.new do |s|
      s.assessment_id = @assessment.id
      s.banner = "DEFAULT BANNER"
      s.colspec = "DEFAULT COLSPEC"
    end
    flash[:info] = "Scoreboard Created" if @scoreboard.save
    redirect_to([:edit, @course, @assessment, :scoreboard]) && return
  end

  action_auth_level :show, :student
  def show
  end

  action_auth_level :edit, :instructor
  def edit
  end

  action_auth_level :update, :instructor
  def update
    flash[:info] = "Saved!" if @scoreboard.update(scoreboard_params)
    redirect_to([:edit, @course, @assessment, :scoreboard]) && return
  end

  action_auth_level :destroy, :instructor
  def destroy
    flash[:info] = "Destroyed!" if @scoreboard.destroy
    redirect_to([:edit, @course, @assessment]) && return
  end

private

  def set_assessment_breadcrumb
    @breadcrumbs << (view_context.link_to "Edit Assessment", [:edit, @course, @assessment])
  end

  def set_scoreboard
    @scoreboard = @assessment.scoreboard
  end
  
  def scoreboard_params
    params[:scoreboard].permit(:banner, :colspec)
  end

end
