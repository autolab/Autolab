require "tango_client"

class AmiImagesController < ApplicationController
  before_action :set_manage_course_breadcrumb

  action_auth_level :index, :instructor
  def index;
    @ami_images = AmiImage.all
  end

  action_auth_level :new, :instructor
  def new;
    @ami_image = AmiImage.new
  end

  action_auth_level :edit, :instructor
  def edit;
    @ami_image = AmiImage.find(params[:id])
  end

  action_auth_level :new_package, :instructor
  def new_package;
    @ami_image = AmiImage.find(params[:id])
  end

  action_auth_level :add_package, :instructor
  def add_package;
    @ami_image = AmiImage.find(params[:id])
    @ami_image.packages << if params[:package_version]
                             "#{params[:package_name]}=#{params[:package_version]}"
                           else
                             params[:package_name]
                           end
    @ami_image.save
    redirect_to edit_course_ami_image_path(@course, @ami_image)
  end

  action_auth_level :create_ami, :instructor
  def create_ami;
    image_name = params[:image_name]
    packages = []
    new_ami = AmiImage.create!(name: image_name, packages: packages)
    redirect_to edit_course_ami_image_path(@course, new_ami)
  end
end