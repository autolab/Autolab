require "tango_client"

module Admin
  class ContainerImagesController < ApplicationController
    skip_before_action :set_course
    skip_before_action :authorize_user_for_course
    skip_before_action :update_persistent_announcements

    before_action :set_container_image, only: [:update, :destroy]

    action_auth_level :index, :administrator
    def index;
      refresh_images
      @container_images = ContainerImage.where(is_public: true)
    end

    action_auth_level :new, :administrator
    def new;
      @container_image = ContainerImage.new(is_public: true)
    end

    action_auth_level :create, :administrator
    def create;
      @container_image = ContainerImage.new(container_image_params)

      @container_image.status = 0
      @container_image.is_public = true
      uploaded_file = params[:container_image][:dockerfile]
      dockerfile_content = uploaded_file.read if uploaded_file.present?

      if dockerfile_content.nil?
        flash[:error] = "Dockerfile is empty or not uploaded."
        redirect_to admin_container_images_path
        return
      end

      if @container_image.save
        begin
          resp = TangoClient.build_image(
            @container_image.name,
            @container_image.id,
            dockerfile_content,
            nil
          )
          if @container_image.update(resp)
            flash[:success] = "Successfully started docker image build process"
            redirect_to admin_container_images_path, notice: "Container image was successfully created."
            return
          else
            flash[:error] = "Successfully started docker image build process, failed to write to DB"
          end
        rescue TangoClient::TangoException => e
          flash[:error] = "Error while setting docker image build process: #{e.message}"
        rescue StandardError => e
          flash[:error] = "Unexpected error occurred: #{e.message}"
        end

        redirect_to admin_container_images_path
      else
        flash[:error] = @container_image.errors.full_messages.to_sentence
        render :new, status: :unprocessable_entity
      end
    end

    action_auth_level :update, :administrator
    def update;
      if @container_image.update(container_image_params)
        redirect_to admin_container_images_path,
                    notice: "Container image was successfully updated."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    action_auth_level :destroy, :administrator
    def destroy;
      @container_image.destroy
      redirect_to admin_container_images_path, notice: "Container image was successfully deleted."
    end

    action_auth_level :refresh_status, :administrator
    def refresh_status;
      @container_image = ContainerImage.find(params[:container_image_id])

      if @container_image.nil?
        redirect_to admin_container_images_path, alert: "Container image not found."
      end

      return if (@container_image.status == "failed") || (@container_image.status == "ready")

      begin
        resp = TangoClient.build_status(@container_image.id)
        updated_status = resp["status"]
        @container_image.update!(
          status: updated_status,
          build_logs: @container_image.build_logs.to_s + resp["logs"]
        )
        if updated_status == 2
          @container_image.update!(image_uri: resp["image_uri"])
        end
      rescue TangoClient::TangoException => e
        flash[:error] = "Error while refreshing docker image build status: #{e.message}"
      rescue StandardError => e
        flash[:error] = "Unexpected error occurred: #{e.message}"
      end
      redirect_to admin_container_image_log_path(@container_image)
    end

    def refresh_all_status;
      redirect_to admin_container_images_path
    end

    def log;
      @container_image = ContainerImage.find(params[:container_image_id])
    end

  private

    def set_container_image;
      @container_image = ContainerImage.find(params[:id])
    end

    def refresh_images;
      begin
        updated_images = TangoClient.all_build_status
        public_images = ContainerImage.where(is_public: true)
        public_images.transaction do
          public_images.each do |image|
            next if image.status == "ready" || image.status == "failed"

            updated_image = updated_images[image.id.to_s]
            if updated_image.nil?
              image.update!(status: "failed")
            else
              updated_status = updated_image["statusId"]
              image.update!(
                status: updated_status,
                build_logs: image.build_logs.to_s + updated_image["logs"].join
              )
              if updated_status == 2
                image.update!(image_uri: updated_image["ecrImageUri"])
              end
            end
          end
        end
      rescue TangoClient::TangoException => e
        flash[:error] = "Error while refreshing docker image build status: #{e.message}"
      rescue StandardError => e
        flash[:error] = "Unexpected error occurred: #{e.message}"
      end
    end

    def container_image_params;
      params.require(:container_image).permit(
        :name,
        :status,
        :image_uri,
        :build_id,
        :is_public,
        :dockerfile
      )
    end
  end
end