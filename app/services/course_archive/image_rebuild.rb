require "tango_client"

module CourseArchive
  # Imported container images arrive as drafts with no image_uri, because the
  # source course's ECR image lives in that course's repository. Ask Tango to
  # rebuild each one from its stored Dockerfile under the new course. When a
  # build finishes, ContainerImage#mark_built! moves the course's autograders
  # onto it; until then they keep the original URI.
  module ImageRebuild
    def self.call(course)
      return unless Rails.configuration.x.ec2_docker == true

      course.container_images.draft.where(image_uri: nil).find_each do |image|
        rebuild(course, image)
      end
    end

    def self.rebuild(course, image)
      if image.dockerfile_contents.blank?
        image.update!(status: :failed,
                      build_logs: "Course import: no Dockerfile was exported for this image")
        return
      end

      response = TangoClient.build_image(image.name, image.id, image.dockerfile_contents,
                                         course.name, nil, nil)
      image.update!(status: response.fetch("status"))
    rescue StandardError => e # includes TangoClient::TangoException
      # The course itself imported fine; an image build failure must not undo it.
      Rails.logger.error("Course import could not rebuild image #{image.id}: #{e.message}")
      image.update(status: :failed, build_logs: "Course import rebuild failed: #{e.message}")
    end
  end
end
