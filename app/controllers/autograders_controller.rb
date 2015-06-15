##
# Each Assessment can have an autograder, which is modified with this controller
#
class AutogradersController < ApplicationController
  before_action :set_assessment
  before_action :set_assessment_breadcrumb, only: [:edit]
  before_action :set_autograder, except: [:create]

  action_auth_level :create, :instructor
  def create
    @autograder = Autograder.new do |a|
      a.assessment_id = @assessment.id
      a.autograde_timeout = 180
      a.autograde_image = "changeme.img"
      a.release_score = true
    end
    flash[:info] = "Autograder Created" if @autograder.save
    redirect_to([:edit, @course, @assessment, :autograder]) && return
  end

  action_auth_level :edit, :instructor
  def edit
    params[:active_tab] ||= "autograder"
    redirect_to(edit_course_assessment_path(@course, @assessment)+"/#{params[:active_tab]}") && return
  end

  action_auth_level :update, :instructor
  def update
    flash[:info] = "Saved!" if @autograder.update(autograder_params)
    redirect_to([:edit, @course, @assessment, :autograder]) && return
  end

  action_auth_level :destroy, :instructor
  def destroy
    flash[:info] = "Destroyed!" if @autograder.destroy
    redirect_to([:edit, @course, @assessment]) && return
  end

private

  def set_assessment_breadcrumb
    @breadcrumbs << (view_context.link_to "Edit Assessment", [:edit, @course, @assessment])
  end

  def set_autograder
    @autograder = @assessment.autograder
    redirect_to([@course, @assessment]) if @autograder.nil?
  end

  def autograder_params
    params[:autograder].permit(:autograde_timeout, :autograde_image, :release_score)
  end
end
