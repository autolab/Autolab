class WatchlistConfiguration < ApplicationRecord
  belongs_to :course

  def self.get_category_blocklist_for_course(course_name)
    # Make sure the course exists
    course = Course.find_by(name: course_name)
    raise "Course #{course_name} cannot be found" if course.nil?

    config = course.watchlist_configuration

    return [] if config.nil?

    return [] if config.category_blocklist.nil?

    config.category_blocklist
  end

  def self.get_assessment_blocklist_for_course(course_name)
    # Make sure the course exists
    course = Course.find_by(name: course_name)
    raise "Course #{course_name} cannot be found" if course.nil?

    config = course.watchlist_configuration

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
  def self.update_watchlist_configuration_for_course(course_name, blocklist_update, allow_ca)
    # Make sure the course exists
    course = Course.find_by(name: course_name)
    raise "Course #{course_name} cannot be found" if course.nil?

    raise "No blocklist update provided." if blocklist_update.nil?
    raise "No allow_ca update provided." if allow_ca.nil?

    config = course.watchlist_configuration
    config ||= WatchlistConfiguration.new(course_id: course.id)

    category_blocklist = blocklist_update[:category]
    assessment_blocklist = blocklist_update[:assessment]

    do_refresh = false

    if config.category_blocklist != category_blocklist
      config.category_blocklist = category_blocklist unless category_blocklist.nil?
      do_refresh = true
    end

    if config.assessment_blocklist != assessment_blocklist
      config.assessment_blocklist = assessment_blocklist unless assessment_blocklist.nil?
      do_refresh = true
    end

    config.allow_ca = allow_ca unless allow_ca.nil?

    raise "Failed to update watchlist configuration for course #{course_name}" unless config.save

    # Refresh watchlist instances if necessary
    WatchlistInstance.refresh_instances_for_course(course_name, true) if do_refresh

    config
  end

  SERIALIZABLE = Set.new %w[category_blocklist assessment_blocklist allow_ca]
  def serialize
    Utilities.serializable attributes, SERIALIZABLE
  end
end
