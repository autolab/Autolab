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

  action_auth_level :destroy, :instructor
  def destroy
    @ami_image = AmiImage.find(params[:id])
    @ami_image.destroy
    redirect_to course_ami_images_path(@course)
  end

  action_auth_level :init_ami, :instructor
  def init_ami;
    image_name = params[:image_name]
    new_ami = AmiImage.create!(name: image_name)
    redirect_to edit_course_ami_image_path(@course, new_ami)
  end

  action_auth_level :create_ami, :instructor
  def create_ami;
    @ami_image = AmiImage.find(params[:id])
    begin
      resp = TangoClient.create_ami(@ami_image.name, @ami_image.emit_packages)
      if @ami_image.update(resp)
        flash[:success] = "Successfully started AMI process"
      else
        flash[:error] = "Successfully started AMI process, failed to write to DB"
      end
    rescue TangoClient::TangoException => e
      flash[:error] = "Error while setting AMI process: #{e.message}"
    rescue StandardError => e
      flash[:error] = "Unexpected error occurred: #{e.message}"
    end
    redirect_to course_ami_images_path(@course)
  end

  action_auth_level :refresh_status, :instructor
  def refresh_status;
    begin
      resp = TangoClient.refresh_ami_status(AmiImage.emit_arn)
      resp.each do |ami|
        ami_image = AmiImage.find(ami["id"])
        ami_image.update!(
          status: ami["status"],
          ami_id: ami["ami_id"],
        )
      end
      flash[:notice] = 'Updated AMI status'
    rescue TangoClient::TangoException => e
      flash[:error] = "Error while refreshing status: #{e.message}"
    rescue StandardError => e
      flash[:error] = "Unexpected error occurred: #{e.message}"
    end
    redirect_to course_ami_images_path(@course)
  end
end
