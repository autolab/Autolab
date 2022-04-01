class WatchlistConfiguration < ApplicationRecord
  belongs_to :course

  def self.get_category_allowlist_for_course(course_name)
    # Make sure the course exists
    course = Course.find_by(name: course_name)
    raise "Course #{course_name} cannot be found" if course.nil?

    config = WatchlistConfiguration.find_by(course_id: course.id)

    return [] if config.nil?

    return [] if config.category_allowlist.nil?

    config.category_allowlist
  end

  def self.get_assessment_allowlist_for_course(course_name)
    # Make sure the course exists
    course = Course.find_by(name: course_name)
    raise "Course #{course_name} cannot be found" if course.nil?

    config = WatchlistConfiguration.find_by(course_id: course.id)

    return [] if config.nil?

    return [] if config.assessment_allowlist.nil?

    config.assessment_allowlist
  end

  # Update watchlist configuration for course with the given course name
  # course_name: string, the name of the course
  # allowlist_update: { :category => ["A", "B", ...], :assessment => ["A", "B", ...]}
  # This method expects that even if the allowlist is updated to be blank, the caller
  # would still provide an empty array as an argument.
  # nil would be interpreted as no change.
  def self.update_watchlist_configuration_for_course(course_name, allowlist_update)
    # Make sure the course exists
    course = Course.find_by(name: course_name)
    raise "Course #{course_name} cannot be found" if course.nil?

    raise "No allowlist update provided." if allowlist_update.nil?

    config = WatchlistConfiguration.find_by(course_id: course.id)
    config ||= WatchlistConfiguration.new(course_id: course.id)

    category_allowlist = allowlist_update[:category]
    assessment_allowlist = allowlist_update[:assessment]

    config.category_allowlist = category_allowlist unless category_allowlist.nil?
    config.assessment_allowlist = assessment_allowlist unless assessment_allowlist.nil?

    raise "Failed to update watchlist configuration for course #{course_name}" unless config.save

    config
  end
end
