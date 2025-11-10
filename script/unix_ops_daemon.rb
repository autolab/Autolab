#!/usr/bin/env ruby
# frozen_string_literal: true
#
# unix_ops_daemon.rb - Lightweight HTTP daemon for privileged Unix operations.
# Runs inside a dedicated container with access to host /etc and /home, exposing
# a simple JSON API for the web application to request user/group changes.
#
# Usage:
#   bundle exec ruby script/unix_ops_daemon.rb
#

ENV["RAILS_ENV"] ||= ENV.fetch("UNIX_OPS_RAILS_ENV", "production")

require "json"
require "webrick"
require "active_support/security_utils"
require_relative "../config/environment"
require_relative "../app/services/unix_group_manager"

module UnixOps
  class Server
    DEFAULT_PORT = (ENV["UNIX_OPS_PORT"] || 4000).to_i
    BIND_ADDRESS = ENV.fetch("UNIX_OPS_BIND", "0.0.0.0")

    def initialize
      @logger = Rails.logger || Logger.new($stdout)
      @server = WEBrick::HTTPServer.new(
        Port: DEFAULT_PORT,
        BindAddress: BIND_ADDRESS,
        AccessLog: [],
        Logger: WEBrick::Log.new($stdout, WEBrick::Log::INFO)
      )
      mount_routes
    end

    def start
      trap("INT") { shutdown }
      trap("TERM") { shutdown }
      @logger.info("UnixOps daemon listening on #{BIND_ADDRESS}:#{DEFAULT_PORT}")
      @server.start
    end

    private

    def mount_routes
      @server.mount_proc "/health" do |_req, res|
        res.status = 200
        res["Content-Type"] = "application/json"
        res.body = JSON.dump(status: "ok")
      end

      @server.mount_proc "/jobs" do |req, res|
        unless authorized?(req)
          respond(res, 401, error: "unauthorized")
          next
        end

        begin
          payload = JSON.parse(req.body.to_s)
        rescue JSON::ParserError
          respond(res, 400, error: "invalid_json")
          next
        end

        action = payload["action"]
        job_payload = payload["payload"] || {}

        success, message, data = process(action, job_payload)
        status = success ? 200 : 422
        respond(res, status, { success: success, message: message, data: data })
      end
    end

    def authorized?(req)
      secret = ENV["UNIX_OPS_SHARED_SECRET"]
      return true if secret.nil? || secret.empty?

      header = req.header["authorization"]&.first
      return false if header.nil? || !header.start_with?("Bearer ")

      token = header.split(" ", 2).last
      # Use secure compare if available
      ActiveSupport::SecurityUtils.secure_compare(token, secret)
    rescue StandardError
      false
    end

    def process(action, payload)
      case action
      when "ensure_group"
        [UnixGroupManager.ensure_group(payload["group_name"]), "ensure_group", nil]
      when "remove_group"
        [UnixGroupManager.remove_group(payload["group_name"], force: payload["force"]), "remove_group", nil]
      when "ensure_user"
        [UnixGroupManager.ensure_user(payload["username"], email: payload["email"]), "ensure_user", nil]
      when "setup_user_home"
        [UnixGroupManager.setup_user_home(payload["username"]), "setup_user_home", nil]
      when "add_user_to_group"
        [UnixGroupManager.add_user_to_group(payload["username"], payload["group_name"]), "add_user_to_group", nil]
      when "remove_user_from_group"
        [UnixGroupManager.remove_user_from_group(payload["username"], payload["group_name"]), "remove_user_from_group", nil]
      when "provision_ssh_key"
        [UnixGroupManager.provision_ssh_key(payload["username"], payload["public_key"], email: payload["email"]), "provision_ssh_key", nil]
      when "deprovision_ssh_key"
        [UnixGroupManager.deprovision_ssh_key(payload["username"], payload["fingerprint"]), "deprovision_ssh_key", nil]
      when "provision_ssh_keys"
        [UnixGroupManager.provision_ssh_keys(payload["username"], payload["public_keys"] || [], email: payload["email"]), "provision_ssh_keys", nil]
      when "delete_user"
        [UnixGroupManager.delete_user(payload["username"], remove_home: payload.fetch("remove_home", true)), "delete_user", nil]
      when "user_exists"
        success = UnixGroupManager.user_exists?(payload["username"])
        [true, "user_exists", { value: success }]
      else
        [false, "unknown_action", nil]
      end
    rescue StandardError => e
      @logger.warn("UnixOps action #{action} failed: #{e.message}")
      [false, e.message, nil]
    end

    def respond(res, status, body)
      data = body.delete(:data)
      res.status = status
      res["Content-Type"] = "application/json"
      res.body = JSON.dump(body.merge(data ? { data: data } : {}))
    end

    def shutdown
      @logger.info("UnixOps daemon shutting down")
      @server.shutdown
    end
  end
end

UnixOps::Server.new.start

