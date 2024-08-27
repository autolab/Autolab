##
# Each Assessment can have an autograder, which is modified with this controller
#
class AutogradersController < ApplicationController
  before_action :set_assessment
  before_action :set_assessment_breadcrumb, only: [:edit]
  before_action :set_edit_assessment_breadcrumb, only: [:edit]
  before_action :set_autograder, except: [:create]

  action_auth_level :create, :instructor
  def create
    @autograder = Autograder.new do |a|
      a.assessment_id = @assessment.id
      a.autograde_timeout = 180
      a.autograde_image = "autograding_image"
      a.release_score = true
    end
    if @autograder.save
      flash[:success] = "Autograder created."
      redirect_to(edit_course_assessment_autograder_path(@course, @assessment))
    else
      flash[:error] = "Autograder could not be created.<br>"
      flash[:error] += @autograder.errors.full_messages.join("<br>")
      flash[:html_safe] = true
      redirect_to(edit_course_assessment_path(@course, @assessment))
    end
  end

  action_auth_level :edit, :instructor
  def edit; end

  action_auth_level :update, :instructor
  def update
    if @autograder.update(autograder_params)
      flash[:success] = "Autograder saved."
      begin
        upload
      rescue StandardError
        flash[:error] = "Autograder could not be uploaded."
      end
    else
      flash[:error] = "Autograder could not be saved.<br>"
      flash[:error] += @autograder.errors.full_messages.join("<br>")
      flash[:html_safe] = true
    end
    redirect_to(edit_course_assessment_autograder_path(@course, @assessment))
  end

  action_auth_level :destroy, :instructor
  def destroy
    if @autograder.destroy
      flash[:success] = "Autograder destroyed."
      redirect_to(edit_course_assessment_path(@course, @assessment))
    else
      flash[:error] = "Autograder could not be destroyed."
      flash[:error] += @autograder.errors.full_messages.join("<br>")
      flash[:html_safe] = true
      redirect_to(edit_course_assessment_autograder_path(@course, @assessment))
    end
  end

  action_auth_level :upload, :instructor
  def upload
    uploaded_makefile = params[:autograder][:makefile]
    uploaded_tar = params[:autograder][:tar]
    unless uploaded_makefile.nil?
      File.open(Rails.root.join("courses", @course.name, @assessment.name, "autograde-Makefile"),
                "wb") do |file|
        file.write(uploaded_makefile.read) unless uploaded_makefile.nil?
      end
    end

    return if uploaded_tar.nil?

    File.open(Rails.root.join("courses", @course.name, @assessment.name, "autograde.tar"),
              "wb") do |file|
      file.write(uploaded_tar.read) unless uploaded_tar.nil?
    end
  end

private

  def set_autograder
    @autograder = @assessment.autograder
    redirect_to(course_assessment_path(@course, @assessment)) if @autograder.nil?
  end

  def autograder_params
    params[:autograder].permit(:autograde_timeout, :autograde_image, :release_score)
  end
end
