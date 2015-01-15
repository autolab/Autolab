class Logger
  def format_message(level, time, progname, msg)
    strTime = time.strftime("%m/%d/%y %H:%M:%S")
    "#{level} -- #{strTime} -- #{msg}\n"
  end
end

class CourseLogger
  def initalize()
    @logger = nil
  end

  def setCourse(course)
    # if this can't grab the file, Autolab should still function
    begin
      @logger = Logger.new("#{Rails.root}/courses/#{course.name}/autolab.log",'monthly')
    rescue
      @logger = nil
    end
  end

  def log(message,severity=Logger::INFO)
    if @logger then
      @logger.add(severity) { message }
    else
      ActionController::Base.logger.add(severity) {message}
    end
  end
end
COURSE_LOGGER = CourseLogger.new()
