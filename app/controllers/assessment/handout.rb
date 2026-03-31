require "archive"

##
# Defines handout method, so students can get handout
#
module AssessmentHandout
  def mime_type_from_ext(ext)
    case ext
    when ".html" then "text/html"
    when ".pdf" then "application/pdf"
    else "application/octet-stream"
    end
  end

  def handout
    # If the logic here changes, do update assessment#has_handout?
    begin
      extend_config_module(@assessment, nil, @cud)
    rescue StandardError => e
      if @cud.has_auth_level? :instructor
        flash[:error] = "Error loading the config file: "
        flash[:error] += e.message
        flash[:error] += "<br/> Try reloading the course config file," \
          " or re-upload the course config file in order to recover your assessment."
        flash[:html_safe] = true
      else
        flash[:error] = "Error loading #{@assessment.display_name}. Please contact your instructor."
      end
      return
    end

    if @assessment.overwrites_method?(:handout)
      hash = @assessment.config_module.handout
      # Ensure that handout lies within the assessment folder
      unless Archive.in_dir?(Pathname(hash["fullpath"]), @assessment.folder_path)
        flash.now[:error] =
          "Invalid handout path: #{hash['fullpath']} does not lie within the assessment folder."
        return
      end

      unless send_handout_file(hash["fullpath"], hash["filename"])
        flash.now[:error] =
          "The handout file could not be found or read. Please contact your instructor."
      end
      return
    end

    redirect_to(@assessment.handout) && return if @assessment.handout_is_url?

    if @assessment.handout_is_file?
      # Note: handout_is_file? validates that the handout lies within the assessment folder
      filename = @assessment.handout_path
      unless send_handout_file(filename)
        flash.now[:error] =
          "The handout file could not be found or read. Please contact your instructor."
      end
      return
    end

    flash.now[:error] = "There is no handout for this assessment."
  end

private

  def send_handout_file(path, download_name = nil)
    filename = download_name || File.basename(path.to_s)

    if File.file?(path) && File.readable?(path)
      send_file(path,
                type: mime_type_from_ext(File.extname(path.to_s)),
                disposition: "inline",
                filename:)
      return true
    end

    content = UnixGroupManager.read_file_via_delegate(path.to_s)
    if content.nil?
      UnixGroupManager.repair_course_directory_access(@course) if @course

      if File.file?(path) && File.readable?(path)
        send_file(path,
                  type: mime_type_from_ext(File.extname(path.to_s)),
                  disposition: "inline",
                  filename:)
        return true
      end

      content = UnixGroupManager.read_file_via_delegate(path.to_s)
      return false if content.nil?
    end

    send_data(content,
              type: mime_type_from_ext(File.extname(path.to_s)),
              disposition: "inline",
              filename:)
    true
  rescue ActionController::MissingFile, Errno::ENOENT, Errno::EACCES, Errno::EPERM => e
    Rails.logger.warn("Failed to stream handout for assessment #{@assessment.id}: #{e.class} - #{e.message}")

    UnixGroupManager.repair_course_directory_access(@course) if @course

    if File.file?(path) && File.readable?(path)
      send_file(path,
                type: mime_type_from_ext(File.extname(path.to_s)),
                disposition: "inline",
                filename:)
      return true
    end

    content = UnixGroupManager.read_file_via_delegate(path.to_s)
    return false if content.nil?

    send_data(content,
              type: mime_type_from_ext(File.extname(path.to_s)),
              disposition: "inline",
              filename:)
    true
  end
end
