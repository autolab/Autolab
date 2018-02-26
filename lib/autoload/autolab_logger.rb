class AutolabFormatter < ::Logger::Formatter
  def call(level, time, _progname, msg)
    strTime = time.strftime("%m/%d/%y %H:%M:%S")
    "#{level} -- #{strTime} -- #{msg}\n"
  end
end

# Globally available logger that can be log to both courses and assessments
# depending on what is currently set.
#
# Invariant: @logger is never nil. It is Rails.logger when not set.
# When @logger is Rails.logger, its formatter should not be set.
class AutolabLogger
  def initalize
    reset
  end

  def reset
    @course = nil
    @assessment = nil
    @formatter = nil
    @logger = Rails.logger
  end

  def setLogPath(path)
    # if this can't grab the file, Autolab should still function by using the
    # default logger
    @logger = Logger.new(path, "monthly")
    @logger.formatter = @formatter || AutolabFormatter.new
  rescue
    @logger = Rails.logger
  end

  def setFormatter(alt_formatter)
    @formatter = alt_formatter
    @logger.formatter = @formatter if @logger != Rails.logger
  end

  def updatePath
    if @course
      if @assessment
        # use assessment log
        setLogPath(Rails.root.join("courses", @course.name, @assessment.name, "log.txt"))
      else
        # use course log
        setLogPath(Rails.root.join("courses", @course.name, "autolab.log"))
      end
    else
      @logger = Rails.logger
    end
  end

  def setCourse(course)
    @course = course
    updatePath
  end

  def setAssessment(assessment)
    @assessment = assessment
    updatePath
  end

  def log(message, severity = Logger::INFO)
    @logger.add(severity) { message }
  end
end

AUTOLAB_LOGGER = AutolabLogger.new
