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
    extend_config_module(@assessment, nil, @cud)

    if @assessment.overwrites_method?(:handout)
      hash = @assessment.config_module.handout
      send_file(hash["fullpath"],
                disposition: "inline",
                filename: hash["filename"])
      return
    end

    redirect_to(@assessment.handout) && return if @assessment.handout_is_url?

    if @assessment.handout_is_file?
      filename = @assessment.handout_path
      send_file(filename,
                disposition: "inline",
                file: File.basename(filename))
      return
    end

    flash.now[:error] = "There is no handout for this assessment."
  end
end
