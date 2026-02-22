#!/usr/bin/env ruby
# frozen_string_literal: true
#
# Ensures the Autolab service user is a member of every course Unix group
# on both the host and inside the running container. Safe to re-run.
#
# Usage:
#   RAILS_ENV=production bin/rails runner script/fix_service_user_groups.rb
#   RAILS_ENV=production bin/rails runner script/fix_service_user_groups.rb --dry-run
#
require_relative "../config/environment"
require_relative "../app/services/unix_group_manager"

SERVICE_USER = "user9999"
DRY_RUN = ARGV.include?("--dry-run")

# Simple logging helpers

def say(msg)
  puts msg
end

def dry?
  DRY_RUN
end

say "=== FIX SERVICE USER GROUPS (#{dry? ? 'dry-run' : 'apply'}) ==="

scope = Course.all

total_groups = 0
updated_groups = 0
failures = 0

scope.find_each do |course|
  total_groups += 1
  group_name = UnixGroupManager.safe_group_name(course.name)

  if group_name.nil? || group_name.empty?
    say "\n[SKIP] #{course.name} - invalid/blank group name"
    failures += 1
    next
  end

  say "\n[COURSE] #{course.name} → group=#{group_name}"

  group_failed = false

  # Ensure the group exists on the host
  if dry?
    say "  [DRY] ensure group #{group_name}"
  else
    unless UnixGroupManager.ensure_group(group_name)
      say "  [ERROR] failed to ensure group #{group_name}"
      failures += 1
      next
    end
  end

  # 2. Add user to group on the Host (Remote Sync)
  if dry?
    say "  [DRY] would add #{SERVICE_USER} to host group #{group_name}"
    remote_success = true
  else
    remote_success = UnixGroupManager.add_user_to_group(SERVICE_USER, group_name)
    if remote_success
      say "  [REMOTE] added/verified #{SERVICE_USER} in #{group_name}"
    else
      say "  [ERROR] failed to add #{SERVICE_USER} to #{group_name} on host"
      group_failed = true
    end
  end

  # 3. Add user to group inside the Container (Local Sync)
  # This stops the 500 errors immediately without a Docker restart
  gid = UnixGroupManager.get_group_gid(group_name)

  if gid.nil?
    say "  [ERROR] missing GID for #{group_name}; cannot ensure local membership"
    local_success = false
    group_failed = true
  elsif dry?
    say "  [DRY] would ensure local membership for #{SERVICE_USER} in #{group_name} (gid #{gid})"
    local_success = true
  else
    local_success = UnixGroupManager.ensure_local_group_membership(SERVICE_USER, group_name, gid_hint: gid)
    if local_success
      say "  [LOCAL] added/verified #{SERVICE_USER} in local group #{group_name} (gid #{gid})"
    else
      say "  [ERROR] failed to ensure local membership for #{SERVICE_USER} in #{group_name}"
      group_failed = true
    end
  end

  # Summary bookkeeping per group
  if group_failed
    failures += 1
  elsif remote_success && local_success
    updated_groups += 1
  end
rescue StandardError => e
  say "  [ERROR] #{e.class}: #{e.message}"
  failures += 1
  next
end

say "\n=== Summary ==="
say "Total groups checked: #{total_groups}"
say "Dual-synced (host + container): #{updated_groups}"
say "Failures: #{failures}"
say "Mode: #{dry? ? 'dry-run (no changes made)' : 'applied'}"
