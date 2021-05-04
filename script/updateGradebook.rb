#!/usr/bin/env ruby
# frozen_string_literal: true

require File.expand_path("#{File.dirname(__FILE__)}/../config/environment")

course_id = ARGV[0]
@course = Course.find(course_id)
exit unless @course

# require(File.expand_path("app/models/gradebook_cache.rb"))

# begin
#	CacheUpdater.update_cache(@course.id)
# rescue StandardError => error
#	puts 'AHHHHHHHHHHH'
#	notify_about_exception(error)
# end
