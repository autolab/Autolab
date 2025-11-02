#!/usr/bin/env ruby
# frozen_string_literal: true
#
# Bootstrap Course Groups - Migrate existing courses to per-course Unix group model
#
# Usage:
#   RAILS_ENV=production bin/rails runner script/bootstrap_course_groups.rb --dry-run
#   RAILS_ENV=production bin/rails runner script/bootstrap_course_groups.rb
#   RAILS_ENV=production bin/rails runner script/bootstrap_course_groups.rb --course="15-122"
#
require "open3"
require_relative "../config/environment"
require_relative "../app/services/unix_group_manager"
require_relative "../app/services/filesystem_enforcer"

DRY_RUN = ARGV.include?("--dry-run")
ONLY_COURSE = ARGV.find { |a| a.start_with?("--course=") }&.split("=", 2)&.last

def say(msg)
  puts msg
end

def sys(cmd)
  say "  [SYS] #{cmd}"
  return true if DRY_RUN

  stdout, stderr, status = Open3.capture3(cmd)
  unless status.success?
    say "  [ERROR] #{cmd}"
    say "    #{stderr}"
    return false
  end
  true
end

def dry?
  DRY_RUN
end

say "=== BOOTSTRAP: DB → Unix groups (#{dry? ? 'dry-run' : 'real'}) ==="

scope = Course.all
scope = scope.where(name: ONLY_COURSE) if ONLY_COURSE

scope.find_each do |course|
  group_name = UnixGroupManager.safe_group_name(course.name)
  unless group_name
    say "\n[SKIP] #{course.name} - invalid group name"
    next
  end

  say "\n[COURSE] #{course.name} → group=#{group_name}"

  # Create Unix group
  if DRY_RUN
    say "  [SYS] groupadd #{group_name}"
  else
    unless UnixGroupManager.ensure_group(group_name)
      say "  [ERROR] Failed to create group #{group_name}"
      next
    end
  end

  # Get all instructors and TAs
  staff_cuds = course.course_user_data.where(instructor: true)
                     .or(course.course_user_data.where(course_assistant: true))

  staff_cuds.find_each do |cud|
    username = UnixGroupManager.login_from_email(cud.user.email)
    unless username
      say "  [SKIP] Invalid username for #{cud.user.email}"
      next
    end

    say "  - add #{cud.user.email} → #{username} to #{group_name}"

    # Create user if needed
    if DRY_RUN
      say "    [SYS] id -u #{username} >/dev/null 2>&1 || useradd -m -s /bin/bash -c \"#{cud.user.email}\" #{username}"
    else
      UnixGroupManager.ensure_user(username, email: cud.user.email)
    end

    # Add user to group
    if DRY_RUN
      say "    [SYS] usermod -a -G #{group_name} #{username}"
    else
      UnixGroupManager.add_user_to_group(username, group_name)
    end
  end

  # Fix permissions on course directory
  course_dir = course.directory_path.to_s
  if Dir.exist?(course_dir)
    if DRY_RUN
      say "  [SYS] chgrp -R #{group_name} #{course_dir}"
      say "  [SYS] find #{course_dir} -type d -exec chmod 2770 {} +"
      say "  [SYS] find #{course_dir} -type f -exec chmod 660 {} +"
    else
      sys("chgrp -R #{group_name} #{course_dir}")
      sys("find #{course_dir} -type d -exec chmod 2770 {} +")
      sys("find #{course_dir} -type f -exec chmod 660 {} +")

      # Also use FilesystemEnforcer to ensure consistency
      FilesystemEnforcer.fix_tree(course_dir)
    end
  else
    say "  [WARN] Course directory #{course_dir} does not exist"
  end
end

say "\n=== Done (#{dry? ? 'dry-run' : 'applied'}) ==="
