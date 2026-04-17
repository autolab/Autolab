#!/usr/bin/env ruby
# frozen_string_literal: true
#
# Bootstrap Course Groups - Create Unix groups for courses
# Note: Unix users are NOT created here - they are created on-demand when staff add SSH keys via web UI
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

say "=== BOOTSTRAP: Create Unix groups for courses (#{dry? ? 'dry-run' : 'real'}) ==="
say "NOTE: Unix users are created on-demand when staff add SSH keys via web UI"
say ""

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
    username = UnixGroupManager.update_unix_user_mapping(cud.user)
    unless username
      say "  [SKIP] Invalid username for #{cud.user.email}"
      next
    end

    say "  - add #{cud.user.email} → #{username} to #{group_name}"

    # Check if user exists (users are created on-demand when SSH key is added)
    if DRY_RUN
      say "    [SYS] id -u #{username} >/dev/null 2>&1 && usermod -a -G #{group_name} #{username}"
      say "    [NOTE] User will be created when they add their first SSH key via web UI"
    else
      stdout, stderr, status = Open3.capture3("id", "-u", username)
      if status.success?
        # User exists - add to group
        if UnixGroupManager.add_user_to_group(username, group_name)
          say "    ✓ Added existing user #{username} to #{group_name}"
        else
          say "    ✗ Failed to add #{username} to #{group_name} - check logs"
        end
      else
        # User doesn't exist yet - that's expected
        say "    ℹ User #{username} will be created when they add SSH key via web UI"
      end
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
