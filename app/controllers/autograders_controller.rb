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
      a.access_key_id = nil if a.respond_to?(:access_key_id=)
      a.access_key = nil if a.respond_to?(:access_key=)
      a.instance_type = "t3.micro" if a.respond_to?(:instance_type=)
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

    @allowed_instance_types = @course.allowed_ec2_instances.presence || ["t2.micro", "t3.micro"]
    @container_images = ContainerImage.ready.where(course: @course)
                                      .or(ContainerImage.ready.where(is_public: true))
                                      .order(created_at: :desc)
  end

  action_auth_level :update, :instructor
  def update
    # Clear secrets if use_access_key is disabled
    params_to_update = autograder_params.to_h.symbolize_keys
    if @autograder.respond_to?(:use_access_key)
      use_access_key_enabled =
        ActiveModel::Type::Boolean.new.cast(params_to_update[:use_access_key])
      params_to_update[:use_access_key] = use_access_key_enabled

      if use_access_key_enabled
        params_to_update.delete(:access_key) if params_to_update[:access_key].blank?
        params_to_update.delete(:access_key_id) if params_to_update[:access_key_id].blank?
      else
        params_to_update[:access_key] = nil
        params_to_update[:access_key_id] = nil
      end
    else
      params_to_update.delete(:use_access_key)
      params_to_update.delete(:access_key)
      params_to_update.delete(:access_key_id)
    end

    params_to_update.delete(:instance_type) unless @autograder.respond_to?(:instance_type)

    if @autograder.update(params_to_update) && @assessment.update(assessment_params)
      flash[:success] = "Autograder saved."
      begin
        upload
      rescue Errno::EACCES, Errno::EPERM => e
        Rails.logger.error("Autograder upload permission error for " \
                             "course=#{@course.name}, assessment=#{@assessment.name}: " \
                             "#{e.class}: #{e.message}")
        flash[:error] = "Autograder could not be uploaded due to filesystem permissions."
      rescue StandardError => e
        Rails.logger.error("Autograder upload failed for course=#{@course.name}, " \
                             "assessment=#{@assessment.name}: " \
                             "#{e.class}: #{e.message}")
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
    uploaded = params.fetch(:autograder, {})
    uploaded_makefile = uploaded[:makefile]
    uploaded_tar = uploaded[:tar]
    return if uploaded_makefile.nil? && uploaded_tar.nil?

    assessment_dir = autograder_directory_path
    unless assessment_dir.directory?
      raise Errno::ENOENT, "Assessment directory does not exist: #{assessment_dir}"
    end

    if UnixGroupManager.delegate_enabled? &&
       !UnixGroupManager.mkdir_p_via_delegate(assessment_dir.to_s)
      raise Errno::EACCES, "Permission denied creating #{assessment_dir}"
    end

    FilesystemEnforcer.fix_path(assessment_dir.to_s)

    unless uploaded_makefile.nil?
      write_uploaded_file(uploaded_makefile,
                          assessment_dir.join("autograde-Makefile"))
    end
    write_uploaded_file(uploaded_tar, assessment_dir.join("autograde.tar")) unless uploaded_tar.nil?
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
    params.require(:autograder).permit(
      :autograde_timeout, :autograde_image, :release_score,
      :use_access_key, :access_key, :access_key_id, :instance_type
    )
  end

  def assessment_params
    params.fetch(:autograder, {}).fetch(:assessment, {}).permit(:disable_network)
  end

  def autograder_directory_path
    Rails.root.join("courses", @course.name, @assessment.name)
  end

  def write_uploaded_file(uploaded_file, destination_path)
    file_content = uploaded_file.read

    if UnixGroupManager.delegate_enabled?
      success = UnixGroupManager.write_file_via_delegate(destination_path.to_s, file_content)
      raise Errno::EACCES, "Permission denied writing #{destination_path}" unless success
    else
      File.open(destination_path, "wb") do |file|
        file.write(file_content)
      end
    end

    FilesystemEnforcer.fix_path(destination_path.to_s)
  end
end
