require "tango_client"

class ContainerImagesController < ApplicationController
  before_action :set_container_image, only: [:update, :destroy]

  action_auth_level :index, :instructor
  def index
    @container_images = ContainerImage.all.order(created_at: :desc)
  end

  action_auth_level :new, :instructor
  def new
    @container_image = ContainerImage.new
  end

  action_auth_level :create, :instructor
  def create
    @container_image = ContainerImage.new(container_image_params)

    if @container_image.save
      redirect_to container_images_path, notice: "Container image was successfully created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  action_auth_level :update, :instructor
  def update
    if @container_image.update(container_image_params)
      redirect_to container_images_path, notice: "Container image was successfully updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  action_auth_level :destroy, :instructor
  def destroy
    @container_image.destroy
    redirect_to container_images_path, notice: "Container image was successfully deleted."
  end

  action_auth_level :refresh_status, :instructor
  def refresh_status

  end

  private

  def set_container_image
    @container_image = ContainerImage.find(params[:id])
  end

  def container_image_params
    params.require(:container_image).permit(
      :name,
      :status,
      :image_uri,
      :build_id,
      :course_id,
      :is_public
    )
  end
end