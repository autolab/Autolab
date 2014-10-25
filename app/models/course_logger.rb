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
    @logger = Logger.new("#{Rails.root}/courses/#{course.name}/autolab.log",'monthly')
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
