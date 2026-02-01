class AmiPackagesController < ApplicationController
  before_action :set_manage_course_breadcrumb

  action_auth_level :new, :instructor
  def new;
    @ami_image = AmiImage.find(params[:ami_image_id])
    @ami_package = @ami_image.ami_packages.new
  end

  action_auth_level :create, :instructor
  def create
    @ami_image = AmiImage.find(params[:ami_image_id])
    @ami_package = @ami_image.ami_packages.new(
      name: params[:package_name],
      version: params[:package_version],
    )

    if @ami_package.save
      redirect_to edit_course_ami_image_path(id: @ami_image.id)
    else
      render :new
    end
  end

  action_auth_level :edit, :instructor
  def edit;
    @ami_image = AmiImage.find(params[:ami_image_id])
    @ami_package = AmiPackage.find(params[:id])
  end

  action_auth_level :update, :instructor
  def update;
    @ami_image = AmiImage.find(params[:ami_image_id])
    @ami_package = @ami_image.ami_packages.find(params[:id])

    if @ami_package.update(ami_package_params)
      redirect_to edit_course_ami_image_path(id: @ami_image.id)
    else
      render :new
    end
  end

  action_auth_level :destroy, :instructor
  def destroy;
    @ami_image = AmiImage.find(params[:ami_image_id])
    @ami_package = @ami_image.ami_packages.find(params[:id])
    if @ami_package.destroy
      redirect_to edit_course_ami_image_path(id: @ami_image.id)
    end
  end

  private

  def ami_package_params
    params.require(:ami_package).permit(:name, :version, :install_type, :ami_package_source_id, :position)
  end
end