module AssessmentHandout

  def mime_type_from_ext(ext)
      case ext
          when ".html" then "text/html"
          when ".pdf" then "application/pdf"
          else "application/octet-stream"
      end
  end
  
  def handout
    get_assessment()
  	extend_config_module(@assessment, nil, @cud)

    if Time.now() < @assessment.start_at && !@cud.instructor? then
      flash[:error] = "This assessment has not started yet."
      return
    end

    if @assessment.overwrites_method?(:handout) then
      hash = @assessment.config_module.handout()
      send_file(hash["fullpath"], 
            :disposition => 'inline', 
            :filename => hash["filename"]) and return
      return
    end

    if @assessment.handout_is_url? then
      redirect_to @assessment.handout
      return
    end

    if @assessment.handout_is_file? then
      filename = @assessment.handout_path
      send_file(filename, 
            :disposition => 'inline', 
            :file => File.basename(filename))
      return
    end

    flash[:error] = "There is no handout for this assessment."
  end
end
  