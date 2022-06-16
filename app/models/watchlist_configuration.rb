class WatchlistConfiguration < ApplicationRecord
  belongs_to :course

  def self.get_category_blocklist_for_course(course_name)
    # Make sure the course exists
    course = Course.find_by(name: course_name)
    raise "Course #{course_name} cannot be found" if course.nil?

    config = WatchlistConfiguration.find_by(course_id: course.id)

    return [] if config.nil?

    return [] if config.category_blocklist.nil?

    config.category_blocklist
  end

  def self.get_assessment_blocklist_for_course(course_name)
    # Make sure the course exists
    course = Course.find_by(name: course_name)
    raise "Course #{course_name} cannot be found" if course.nil?

    config = WatchlistConfiguration.find_by(course_id: course.id)

    return [] if config.nil?

    return [] if config.assessment_blocklist.nil?

    config.assessment_blocklist
  end

  # Update watchlist configuration for course with the given course name
  # course_name: string, the name of the course
  # blocklist_update: { :category => ["A", "B", ...], :assessment => ["A", "B", ...]}
  # This method expects that even if the blocklist is updated to be blank, the caller
  # would still provide an empty array as an argument.
  # nil would be interpreted as no change.
  def self.update_watchlist_configuration_for_course(course_name, blocklist_update)
    # Make sure the course exists
    course = Course.find_by(name: course_name)
    raise "Course #{course_name} cannot be found" if course.nil?

    raise "No blocklist update provided." if blocklist_update.nil?

    config = WatchlistConfiguration.find_by(course_id: course.id)
    config ||= WatchlistConfiguration.new(course_id: course.id)

    category_blocklist = blocklist_update[:category]
    assessment_blocklist = blocklist_update[:assessment]

    config.category_blocklist = category_blocklist unless category_blocklist.nil?
    config.assessment_blocklist = assessment_blocklist unless assessment_blocklist.nil?

    raise "Failed to update watchlist configuration for course #{course_name}" unless config.save

    WatchlistInstance.refresh_instances_for_course(course_name, true)

    config
  end
end
