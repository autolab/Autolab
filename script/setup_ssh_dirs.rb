#!/usr/bin/env ruby
# frozen_string_literal: true
#
# Setup SSH directories for existing Unix users
#
# Usage:
#   RAILS_ENV=production bin/rails runner script/setup_ssh_dirs.rb
#
require_relative "../config/environment"
require_relative "../app/services/unix_group_manager"

puts "=== Setting up SSH directories for all staff users ==="

# Get all staff users (instructors and TAs)
staff_users = User.joins(:course_user_data)
                  .where(course_user_data: { instructor: true })
                  .or(User.joins(:course_user_data).where(course_user_data: { course_assistant: true }))
                  .distinct

staff_users.find_each do |user|
  username = UnixGroupManager.update_unix_user_mapping(user)
  next unless username

  puts "\nSetting up SSH for #{user.email} → #{username}"
  
  if UnixGroupManager.setup_user_home(username)
    puts "  ✓ SSH directory setup complete"
    
    # Verify it was created
    stdout, stderr, status = Open3.capture3("getent", "passwd", username)
    if status.success?
      home_dir = stdout.split(":")[5]
      ssh_dir = File.join(home_dir, ".ssh")
      if Dir.exist?(ssh_dir)
        puts "  ✓ .ssh directory exists: #{ssh_dir}"
      else
        puts "  ✗ .ssh directory missing: #{ssh_dir}"
      end
    end
  else
    puts "  ✗ Failed to setup SSH directory - check logs"
  end
end

puts "\n=== Done ==="

