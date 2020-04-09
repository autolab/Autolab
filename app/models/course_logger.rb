class AutolabFormatter < ::Logger::Formatter
  def call(level, time, _progname, msg)
    strTime = time.strftime("%m/%d/%y %H:%M:%S")
    "#{level} -- #{strTime} -- #{msg}\n"
  end
end

class CustomLogger
  def initalize
    resetPath
  end

  def setLogPath(path)
    # if this can't grab the file, Autolab should still function
    @logger = Logger.new(path, "monthly")
    @logger.formatter = AutolabFormatter.new
  rescue
    @logger = Rails.logger
  end

  def resetPath
    @logger = Rails.logger
  end

  def log(message, severity = Logger::INFO)
    unless Rails.env == "test" || Rails.env == "development"
      @logger.add(severity) { message }
    end
  end
end
class CourseLogger < CustomLogger
  def setCourse(course)
    setLogPath(Rails.root.join("courses", course.name, "autolab.log"))
  end
end

class AssessmentLogger < CustomLogger
  def initalize
    @course = nil
    @assessment = nil
  end
  def setCourse(course)
    @course = course
    @assessment = nil
    resetPath
  end
  def setAssessment(assessment)
    @assessment = assessment
    setLogPath(Rails.root.join("courses", @course.name, @assessment.name, "log.txt"))
  end
end

COURSE_LOGGER = CourseLogger.new
ASSESSMENT_LOGGER = AssessmentLogger.new
