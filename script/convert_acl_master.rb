#!/usr/bin/env ruby
# frozen_string_literal: true
#
# Usage:
#   RAILS_ENV=production bin/rails runner script/convert_acl_master.rb --dry-run
#   RAILS_ENV=production bin/rails runner script/convert_acl_master.rb --apply
#   RAILS_ENV=production bin/rails runner script/convert_acl_master.rb --apply --course="15-122"
#
require "open3"
require_relative "../config/environment"

# === Policy (match your chosen model) ===
MODE_DIR  = 0o2770  # drwxrws---
MODE_FILE = 0o660   # -rw-rw----
COURSE_ROOT = Rails.root.join("courses").to_s
ALLOW_ROLES = %w[instructor course_assistant grader] # exclude students

APPLY = ARGV.include?("--apply")
ONLY_COURSE = ARGV.find { |a| a.start_with?("--course=") }&.split("=", 2)&.last

def dry?
  !APPLY
end

def say(msg)  puts msg; end
def warnx(m)  puts "  [WARN] #{m}"; end

def sys(cmd)
  say "[SYS] #{cmd}"
  return if dry?
  out, err, st = Open3.capture3(cmd)
  raise "[ERR] #{cmd}\n#{err}" unless st.success?
  out
end

# Accept Linux-friendly group names. Keep digits, letters, dot, underscore, dash.
def safe_group_name(name)
  g = (name || "").dup
  g = g.strip
  g = g.gsub(/[^A-Za-z0-9._-]/, "-")
  g = g[0, 32] # keep it sane
  g = "grp-#{g}" if g.empty? || g.start_with?("-", ".")
  g
end

# Normalize a login from email. Letters/digits/_- only; lowercased; prefix if invalid start.
def login_from_email(email)
  base = (email || "").split("@").first.to_s.downcase
  base = base.gsub(/[^a-z0-9_-]/, "-")
  base = "u#{base}" unless base =~ /\A[a-z]/
  base = base[0, 32]
  base = "uuser" if base.empty?
  base
end

def ensure_group(group)
  sys("getent group #{group} || groupadd #{group}")
end

def ensure_user(login)
  # Create a local user with home dir and bash shell if missing (no password set)
  sys("id -u #{login} >/dev/null 2>&1 || useradd -m -s /bin/bash #{login}")
end

def ensure_membership(group, login)
  sys("id -nG #{login} | tr ' ' '\\n' | grep -qx #{group} || usermod -a -G #{group} #{login}")
end

def fix_permissions(group, path)
  unless Dir.exist?(path)
    warnx "course dir #{path} missing"
    return
  end
  sys("chgrp -R #{group} #{path}")
  sys("find #{path} -type d -exec chmod #{MODE_DIR.to_s(8)} {} +")
  sys("find #{path} -type f -exec chmod #{MODE_FILE.to_s(8)} {} +")
end

say "=== CONVERT ACL MASTER (#{dry? ? 'dry-run' : 'apply'}) ==="

scope = Course.all
scope = scope.where(name: ONLY_COURSE) if ONLY_COURSE

scope.find_each do |course|
  raw_group = course.name.presence || course.display_name
  group = safe_group_name(raw_group)
  say "\n[COURSE] #{course.name} → group=#{group}"

  ensure_group(group)

  staff = course.course_user_data.where(role: ALLOW_ROLES)
  staff.each do |cud|
    login = login_from_email(cud.user.email)
    say "  - add #{cud.user.email} → #{login} to #{group}"
    ensure_user(login)
    ensure_membership(group, login)
  end

  path = File.join(COURSE_ROOT, group) # directory name = group (safe)
  # If your on-disk dir actually uses course.name: change this to course.name
  fix_permissions(group, path)
end

say "\n=== Done (#{dry? ? 'dry-run' : 'applied'}) ==="