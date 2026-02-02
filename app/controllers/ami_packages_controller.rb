class AmiPackagesController < ApplicationController
  before_action :set_manage_course_breadcrumb

  action_auth_level :new, :instructor
  def new;
    @ami_image = AmiImage.find(params[:ami_image_id])
    @ami_package = @ami_image.ami_packages.new
    @sources = @ami_image.ami_package_sources
  end

  action_auth_level :deb_new, :instructor
  def deb_new
    @ami_image = AmiImage.find(params[:ami_image_id])
    @ami_package = @ami_image.ami_packages.new
    @sources = @ami_image.ami_package_sources
  end

  action_auth_level :create, :instructor
  def create
    @ami_image = AmiImage.find(params[:ami_image_id])
    if params[:deb_url]
      source = @ami_image.ami_package_sources.find_or_create_by(deb_url: params[:deb_url]) do |pkg_src|
        pkg_src.name = params[:package_name]
        pkg_src.source_type = "deb_url"
      end
      @ami_package = @ami_image.ami_packages.new(
        name: params[:package_name],
        install_type: 1,
        ami_package_source_id: source.id
      )
    else
      @ami_package = @ami_image.ami_packages.new(
        name: params[:package_name],
        version: params[:package_version],
      )
    end

    if @ami_package.save
      redirect_to edit_course_ami_image_path(id: @ami_image.id)
    else
      render :new
    end
  end

  action_auth_level :edit, :instructor
  def edit;
    @ami_image = AmiImage.find(params[:ami_image_id])
    @ami_package = @ami_image.ami_packages.find(params[:id])
    @sources = @ami_image.ami_package_sources
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