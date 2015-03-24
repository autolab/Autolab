require "httparty"
require Rails.root.join("config", "autogradeConfig.rb")

##
# Ruby API Client of Tango
module TangoClient
  # Httparty client for Tango API
  class ClientObj
    include HTTParty
    base_uri "#{RESTFUL_HOST}:#{RESTFUL_PORT}"
    default_timeout 10
  end

  # Exception for Tango API Client
  class TangoException < StandardError; end

  def self.tango_handle_timeouts
    resp = yield
    if resp.content_type == "application/json" && resp["statusId"] && resp["statusId"] < 0
      fail TangoException, "Tango returned negative status code."
    end
    return resp
  rescue Net::OpenTimeout, Net::ReadTimeout
    raise TangoException, "Connection timed out with Tango."
  rescue StandardError => e
    raise TangoException, "Unexpected error with Tango (#{e})."
  end

  def self.tango_open(courselab)
    tango_handle_timeouts do
      url = "/open/#{api_key}/#{courselab}/"
      ClientObj.get(url)
    end
  end

  def self.tango_upload(courselab, filename, file)
    tango_handle_timeouts do
      url = "/upload/#{api_key}/#{courselab}/"
      ClientObj.post(url, headers: { "filename" => filename }, body: file)
    end
  end

  def self.tango_addjob(courselab, options = {})
    tango_handle_timeouts do
      url = "/addJob/#{api_key}/#{courselab}/"
      ClientObj.post(url, body: options)
    end
  end

  def self.tango_poll(courselab, output_file)
    tango_handle_timeouts do
      url = "/poll/#{api_key}/#{courselab}/#{output_file}"
      ClientObj.get(url)
    end
  end

  def self.tango_info(courselab)
    tango_handle_timeouts do
      url = "/info/#{api_key}/#{courselab}/"
      ClientObj.get(url)
    end
  end

  def self.tango_jobs(deadjobs = 0)
    tango_handle_timeouts do
      url = "/jobs/#{api_key}/#{deadjobs}/"
      ClientObj.get(url)
    end
  end

  def self.tango_pool(image)
    tango_handle_timeouts do
      url = "/pool/#{api_key}/#{image}/"
      ClientObj.get(url)
    end
  end

  def self.tango_prealloc(image, num, options = {})
    tango_handle_timeouts do
      url = "/prealloc/#{api_key}/#{image}/#{num}/"
      ClientObj.get(url, body: options)
    end
  end

  def self.api_key
    RESTFUL_KEY
  end
end
