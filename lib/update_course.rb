class Updater
    def self.update(course)
      # Simulate some processing
      sleep(2) # Simulate a time-consuming task
      "Successfully updated the course: #{course.name}"
    end
  end
  
  # Simulated course class
  class Course
    attr_accessor :name
  
    def initialize(name)
      @name = name
    end
  end
  
  # This is where the action gets executed with a simulated course
  if __FILE__ == $0
    course = Course.new("Introduction to Ruby")
    puts Updater.update(course)
  end