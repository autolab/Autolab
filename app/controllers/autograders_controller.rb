##
# Each Assessment can have an autograder, which is modified with this controller

require 'pathname'

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
  def edit
    makefile_path = Rails.root.join("courses", @course.name, @assessment.name, "autograde-Makefile")
    tar_path = Rails.root.join("courses", @course.name, @assessment.name, "autograde.tar")
    @makefile_exists = File.exist?(makefile_path) ? makefile_path : nil
    @tar_exists = File.exist?(tar_path) ? tar_path : nil
  end

  action_auth_level :update, :instructor
  def update
    if @autograder.update(autograder_params) && @assessment.update(assessment_params)
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

  action_auth_level :download_file, :instructor
  def download_file
    allowed_files = {
      'makefile' => Rails.root.join('courses', @course.name, @assessment.name,
                                    'autograde-Makefile'),
      'tar' => Rails.root.join('courses', @course.name, @assessment.name, 'autograde.tar')
    }

    file_key = params[:file_key]
    file_path = allowed_files[file_key]

    if file_path && File.exist?(file_path)
      send_file(file_path, disposition: 'attachment')
    else
      flash[:error] = 'File not found'
      redirect_to(edit_course_assessment_autograder_path(@course, @assessment))
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

  def assessment_params
    params.fetch(:autograder, {}).fetch(:assessment, {}).permit(:disable_network)
  end
end
