class AmiPackageSourcesController < ApplicationController
  before_action :set_manage_course_breadcrumb

  action_auth_level :new, :instructor
  def new
    @ami_image = AmiImage.find(params[:ami_image_id])
    @ami_package_source = @ami_image.ami_package_sources.new
  end

  action_auth_level :create, :instructor
  def create
    @ami_image = AmiImage.find(params[:ami_image_id])
    @ami_package_source = @ami_image.ami_package_sources.new(ami_package_source_params)

    if @ami_package_source.save
      redirect_to edit_course_ami_image_path(id: @ami_image.id)
    else
      render :new
    end
  end

  action_auth_level :edit, :instructor
  def edit
    @ami_image = AmiImage.find(params[:ami_image_id])
    @ami_package_source = @ami_image.ami_package_sources.find(params[:id])
  end

  action_auth_level :update, :instructor
  def update
    @ami_image = AmiImage.find(params[:ami_image_id])
    @ami_package_source = @ami_image.ami_package_sources.find(params[:id])

    if @ami_package_source.update(ami_package_source_params)
      redirect_to edit_course_ami_image_path(id: @ami_image.id)
    else
      render :edit
    end
  end

  action_auth_level :destroy, :instructor
  def destroy
    @ami_image = AmiImage.find(params[:ami_image_id])
    @ami_package_source = @ami_image.ami_package_sources.find(params[:id])

    if @ami_package_source.destroy
      redirect_to edit_course_ami_image_path(id: @ami_image.id)
    else
      redirect_to edit_course_ami_image_path(id: @ami_image.id)
    end
  end

  private
  def ami_package_source_params
    params.permit(:name, :source_type, :ami_image_id, :deb_url)
  end
end