#!/usr/bin/env ruby
# frozen_string_literal: true
#
# Transfer ownership of course files/dirs from root to app.
#
# When FilesystemEnforcer sets directory ownership to "root" during course
# creation or enforcement, those paths must later be reassigned to a normal
# service account ("app") so the Rails process (and the unixops daemon) can
# manage them without needing root privileges at runtime.
#
# What it does
# ------------
#   1. Iterates every course directory under Rails.root/courses/.
#   2. Finds all files and directories owned by root (uid 0) within each course.
#   3. Changes their owner to "app" (configurable via --owner=<name>).
#   4. Preserves group ownership and permissions.
#   5. When UNIX_OPS_DELEGATE_URL is set, delegates each chown to the unixops
#      container (same as FilesystemEnforcer); otherwise runs the operation
#      directly via shell (requires the process itself to be root or have
#      CAP_CHOWN).
#
# Usage
# -----
#   # Dry-run (default – just prints what would change)
#   RAILS_ENV=production bin/rails runner script/transfer_root_ownership_to_app.rb
#
#   # Apply changes
#   RAILS_ENV=production bin/rails runner script/transfer_root_ownership_to_app.rb --apply
#
#   # Scope to a single course
#   RAILS_ENV=production bin/rails runner script/transfer_root_ownership_to_app.rb --apply --course="15-122"
#
#   # Override the target owner (default: app)
#   RAILS_ENV=production bin/rails runner script/transfer_root_ownership_to_app.rb --apply --owner=autolab
#
require "open3"
require "etc"
require "find"
require_relative "../config/environment"
require_relative "../app/services/unix_group_manager"

# ---------------------------------------------------------------------------
# CLI flags
# ---------------------------------------------------------------------------
APPLY       = ARGV.include?("--apply")
ONLY_COURSE = ARGV.find { |a| a.start_with?("--course=") }&.split("=", 2)&.last
TARGET_OWNER = (ARGV.find { |a| a.start_with?("--owner=") }&.split("=", 2)&.last || "app").strip

COURSES_ROOT = Rails.root.join("courses").to_s

def dry?
  !APPLY
end

def say(msg)
  puts msg
end

def warn_msg(msg)
  puts "  [WARN]  #{msg}"
end

def error_msg(msg)
  puts "  [ERROR] #{msg}"
end

# ---------------------------------------------------------------------------
# Low-level helpers
# ---------------------------------------------------------------------------

# Returns the uid of +username+ (local lookup only – not via delegate, since
# the delegate doesn't expose a get_user_uid that we can always rely on here).
def resolve_uid(username)
  Etc.getpwnam(username).uid
rescue ArgumentError
  nil
end

# Returns the string owner name for a uid (best-effort).
def owner_name_for(uid)
  Etc.getpwuid(uid).name
rescue ArgumentError
  "uid:#{uid}"
end

# Perform a single chown via the delegate when configured, otherwise shell out.
# We keep the group intact (pass nil as group → "keep current").
def chown_path(path, target_user)
  if dry?
    say "    [DRY] chown #{target_user} #{path}"
    return true
  end

  if UnixGroupManager.delegate_enabled?
    # UnixGroupManager.chgrp_path accepts an owner: kwarg and uses the
    # existing "chgrp" delegate action (which also honours the owner field).
    # We need to preserve the current group, so we look it up first.
    begin
      current_gid = File.stat(path).gid
      current_group = Etc.getgrgid(current_gid).name
    rescue StandardError
      current_group = nil
    end

    if current_group
      success = UnixGroupManager.chgrp_path(path, current_group, owner: target_user)
    else
      # Group unknown – delegate a chown-only action via the generic job endpoint.
      success, _ = UnixGroupManager.call_delegate("chown", path: path, owner: target_user)
    end

    unless success
      error_msg "delegate chown failed for #{path}"
    end
    success
  else
    # Direct shell execution (process must be root or have CAP_CHOWN).
    _out, err, status = Open3.capture3("chown", target_user, path)
    unless status.success?
      error_msg "chown #{target_user} #{path} — #{err.strip}"
    end
    status.success?
  end
end

# ---------------------------------------------------------------------------
# Pre-flight checks
# ---------------------------------------------------------------------------
say "=== TRANSFER ROOT→#{TARGET_OWNER} OWNERSHIP (#{dry? ? 'dry-run – pass --apply to make changes' : 'APPLY'}) ==="
say ""

unless Dir.exist?(COURSES_ROOT)
  error_msg "courses root not found: #{COURSES_ROOT}"
  exit 1
end

target_uid = resolve_uid(TARGET_OWNER)
if target_uid.nil? && !UnixGroupManager.delegate_enabled?
  # Warn but continue – the user may only exist on the host (delegate scenario).
  warn_msg "User '#{TARGET_OWNER}' not found locally; continuing (may be a host-only account)."
end

root_uid = 0  # POSIX root is always uid 0

# ---------------------------------------------------------------------------
# Main loop
# ---------------------------------------------------------------------------
courses_scope = Course.all
courses_scope = courses_scope.where(name: ONLY_COURSE) if ONLY_COURSE

total_courses  = 0
total_paths    = 0
changed_paths  = 0
skipped_paths  = 0
error_count    = 0

courses_scope.find_each do |course|
  course_dir = File.join(COURSES_ROOT, course.name)

  unless Dir.exist?(course_dir)
    say "\n[SKIP] #{course.name} – directory not found (#{course_dir})"
    next
  end

  total_courses += 1
  say "\n[COURSE] #{course.name}  →  #{course_dir}"

  # Walk the entire tree including the course root itself.
  paths_to_inspect = []
  begin
    Find.find(course_dir) do |path|
      next if path == course_dir && false  # include root too
      paths_to_inspect << path
    end
  rescue Errno::EACCES => e
    warn_msg "cannot walk #{course_dir}: #{e.message}"
  end

  # Prepend the course root directory itself so ownership is fixed even when
  # the directory is otherwise inaccessible.
  paths_to_inspect.unshift(course_dir) unless paths_to_inspect.first == course_dir

  paths_to_inspect.each do |path|
    total_paths += 1

    begin
      stat = File.lstat(path)  # lstat – don't follow symlinks
    rescue Errno::ENOENT
      skipped_paths += 1
      next  # vanished between find and stat
    rescue StandardError => e
      warn_msg "stat failed for #{path}: #{e.message}"
      error_count += 1
      next
    end

    unless stat.uid == root_uid
      skipped_paths += 1
      next  # not owned by root – nothing to do
    end

    say "  [CHOWN] #{owner_name_for(stat.uid)} → #{TARGET_OWNER}  #{path}"
    changed_paths += 1

    if chown_path(path, TARGET_OWNER)
      say "    [OK]" unless dry?
    else
      error_count += 1
    end
  end
end

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
say ""
say "=== SUMMARY ==="
say "  Courses inspected : #{total_courses}"
say "  Paths examined    : #{total_paths}"
say "  Root-owned found  : #{changed_paths}"
say "  Unchanged (skipped): #{skipped_paths}"
say "  Errors            : #{error_count}"
say ""
if dry?
  say "  ** Dry-run complete. Re-run with --apply to commit changes. **"
else
  say "  ** Done. #{changed_paths - error_count} path(s) transferred to '#{TARGET_OWNER}'. **"
end
