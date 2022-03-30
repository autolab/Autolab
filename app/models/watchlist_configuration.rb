class WatchlistConfiguration < ApplicationRecord
  belongs_to :course

  # Update watchlist configuration for course with the given course name
  # course_name: string, the name of the course
  # allowlist_update: { :category => ["A", "B", ...], :assessment => ["A", "B", ...]}
  def self.update_watchlist_configuration_for_course(course_name, allowlist_update)
    # Make sure the course exists
    course = Course.find_by(name: course_name)
    raise "Course #{course_name} cannot be found" if course.nil?

    config = WatchlistConfiguration.find_by(course_id: course.id)
    config ||= WatchlistConfiguration.new(course_id: course.id)

    category_allowlist = allowlist_update[:category]
    assessment_allowlist = allowlist_update[:assessment]

    config.assessment_category_allowlist = category_allowlist unless category_allowlist.nil?
    config.assessment_allowlist = assessment_allowlist unless assessment_allowlist.nil?

    raise "Failed to update watchlist configuration for course #{course_name}" unless config.save
  end
end
