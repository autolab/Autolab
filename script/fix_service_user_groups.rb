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
require "open3"
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

# Best-effort check if the user is already in the group on the host
# (delegated environments may not reflect accurately, but good enough for logging)
def remote_group_member?(username, group_name)
  stdout, _stderr, status = Open3.capture3("id", "-nG", username)
  status.success? && stdout.split.include?(group_name)
rescue StandardError
  false
end

say "=== FIX SERVICE USER GROUPS (#{dry? ? 'dry-run' : 'apply'}) ==="

scope = Course.all

total_groups = 0
updated_groups = 0
already_correct = 0
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
  group_updated = false

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

  # Remote (host) membership
  remote_before = remote_group_member?(SERVICE_USER, group_name)
  remote_after = remote_before

  if remote_before
    say "  [REMOTE] #{SERVICE_USER} already in #{group_name}"
  elsif dry?
    say "  [DRY] would add #{SERVICE_USER} to host group #{group_name}"
    group_updated = true
  else
    if UnixGroupManager.add_user_to_group(SERVICE_USER, group_name)
      say "  [REMOTE] added #{SERVICE_USER} to #{group_name}"
      remote_after = true
      group_updated = true
    else
      say "  [ERROR] failed to add #{SERVICE_USER} to #{group_name} on host"
      group_failed = true
    end
  end

  # Local (container) membership
  local_before = UnixGroupManager.local_group_member?(SERVICE_USER, group_name)
  local_after = local_before

  # if local_before
  #   say "  [LOCAL] #{SERVICE_USER} already in #{group_name}"
  # else
  #   gid = UnixGroupManager.get_group_gid(group_name)

  #   if gid.nil?
  #     say "  [ERROR] missing GID for #{group_name}; cannot ensure local membership"
  #     group_failed = true
  #   elsif dry?
  #     say "  [DRY] would ensure local membership for #{SERVICE_USER} in #{group_name} (gid #{gid})"
  #     group_updated = true
  #   else
  #     if UnixGroupManager.ensure_local_group_membership(SERVICE_USER, group_name, gid_hint: gid)
  #       say "  [LOCAL] added #{SERVICE_USER} to local group #{group_name} (gid #{gid})"
  #       local_after = true
  #       group_updated = true
  #     else
  #       say "  [ERROR] failed to ensure local membership for #{SERVICE_USER} in #{group_name}"
  #       group_failed = true
  #     end
  #   end
  # end

  gid = UnixGroupManager.get_group_gid(group_name)

  if gid.nil?
    say "  [ERROR] missing GID for #{group_name}; cannot ensure local membership"
    group_failed = true
  elsif dry?
    say "  [DRY] would ensure local membership for #{SERVICE_USER} in #{group_name} (gid #{gid})"
    group_updated = true
  else
    if UnixGroupManager.ensure_local_group_membership(SERVICE_USER, group_name, gid_hint: gid)
      say "  [LOCAL] added #{SERVICE_USER} to local group #{group_name} (gid #{gid})"
      local_after = true
      group_updated = true
    else
      say "  [ERROR] failed to ensure local membership for #{SERVICE_USER} in #{group_name}"
      group_failed = true
    end
  end

  # Summary bookkeeping per group
  if group_failed
    failures += 1
  elsif remote_after && local_after && !group_updated
    already_correct += 1
  elsif group_updated
    updated_groups += 1
  end
rescue StandardError => e
  say "  [ERROR] #{e.class}: #{e.message}"
  failures += 1
  next
end

say "\n=== Summary ==="
say "Total groups checked: #{total_groups}"
say "Updated (remote and/or local): #{updated_groups}"
say "Already correct: #{already_correct}"
say "Failures: #{failures}"
say "Mode: #{dry? ? 'dry-run (no changes made)' : 'applied'}"
