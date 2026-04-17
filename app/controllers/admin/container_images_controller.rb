require "tango_client"

module Admin
  class ContainerImagesController < ApplicationController
    skip_before_action :set_course
    skip_before_action :authorize_user_for_course
    skip_before_action :update_persistent_announcements

    before_action :set_container_image, only: [:admin_update, :admin_destroy]

    action_auth_level :admin_index, :administrator
    def admin_index;
      refresh_images
      @container_images = ContainerImage.where(is_public: true).order(created_at: :desc)
    end

    action_auth_level :admin_new, :administrator
    def admin_new;
      @container_image = ContainerImage.new(is_public: true)
    end

    action_auth_level :admin_create, :administrator
    def admin_create;
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
            nil,
            nil,
            nil
          )
          if @container_image.update(resp)
            flash[:success] = "Successfully started docker image build process"
            redirect_to admin_container_images_path,
                        notice: "Container image was successfully created."
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
        render :admin_new, status: :unprocessable_entity
      end
    end

    action_auth_level :admin_update, :administrator
    def admin_update;
      if @container_image.update(container_image_params)
        redirect_to admin_container_images_path,
                    notice: "Container image was successfully updated."
      else
        flash[:error] = @container_image.errors.full_messages.to_sentence
        redirect_to admin_container_images_path
      end
    end

    action_auth_level :admin_destroy, :administrator
    def admin_destroy;
      @container_image.destroy
      redirect_to admin_container_images_path, notice: "Container image was successfully deleted."
    end

    action_auth_level :admin_refresh_status, :administrator
    def admin_refresh_status;
      @container_image = ContainerImage.find(params[:id])

      if @container_image.nil?
        redirect_to admin_container_images_path, alert: "Container image not found."
      end

      return if (@container_image.status == "failed") || (@container_image.status == "ready")

      begin
        resp = TangoClient.build_status(@container_image.id)
        updated_status = resp["status"]
        @container_image.update!(
          status: updated_status,
          build_logs: resp["logs"]
        )
        if updated_status == 2
          @container_image.update!(image_uri: resp["image_uri"])
        end
      rescue TangoClient::TangoException => e
        flash[:error] = "Error while refreshing docker image build status: #{e.message}"
      rescue StandardError => e
        flash[:error] = "Unexpected error occurred: #{e.message}"
      end
      redirect_to log_admin_container_image_path(@container_image)
    end

    action_auth_level :admin_refresh_all_status, :administrator
    def admin_refresh_all_status;
      redirect_to admin_container_images_path
    end

    action_auth_level :admin_log, :administrator
    def admin_log;
      @container_image = ContainerImage.find(params[:id])
    end

  private

    def set_container_image;
      @container_image = ContainerImage.find(params[:id])
    end

    def refresh_images;
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
              build_logs: updated_image["logs"].join
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
