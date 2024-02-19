require "httparty"
require "cgi"
require Rails.root.join("config", "autogradeConfig.rb")

##
# Ruby API Client of Tango
module TangoClient
  # Httparty client for Tango API
  class ClientObj
    include HTTParty
    base_uri "#{RESTFUL_HOST}:#{RESTFUL_PORT}"
    default_timeout 30
  end

  # Exception for Tango API Client
  class TangoException < StandardError; end

  # Retries for http operations
  NUM_RETRIES = 3
  RETRY_WAIT_TIME = 2 # seconds

  def self.handle_exceptions
    begin
      retries_remaining ||= NUM_RETRIES
      resp = yield
    rescue Net::OpenTimeout, Net::ReadTimeout, Timeout::Error,
           Errno::ECONNRESET, Errno::ECONNABORTED, Errno::EPIPE => e
      if retries_remaining > 0
        retries_remaining -= 1
        sleep RETRY_WAIT_TIME
        retry
      else
        raise TangoException, "Connection error with Tango (#{e})."
      end
    rescue StandardError => e
      raise TangoException, "Unexpected error with Tango (#{e})."
    end

    if resp.content_type == "application/json" && resp["statusId"] && resp["statusId"] < 0
      raise TangoException, "Tango returned negative status code: #{resp["statusMsg"]}"
    end

    if resp.code != 200
      raise TangoException, "Tango returned HTTP code #{resp.code}"
    end
    
    return resp
  end

  def self.open(courselab)
    resp = handle_exceptions do
      url = "/open/#{api_key}/#{courselab}/"
      ClientObj.get(url)
    end
    resp["files"]
  end

  def self.upload(courselab, filename, file)
    handle_exceptions do
      url = "/upload/#{api_key}/#{courselab}/"
      ClientObj.post(url, headers: { "filename" => filename }, body: file)
    end
  end

  def self.addjob(courselab, options = {})
    handle_exceptions do
      url = "/addJob/#{api_key}/#{courselab}/"
      ClientObj.post(url, body: options)
    end
  end

  def self.poll(courselab, output_file)
    handle_exceptions do
      url = "/poll/#{api_key}/#{courselab}/#{output_file}"
      ClientObj.get(url)
    end
  end

  def self.getpartialoutput(job_id)
    resp = handle_exceptions do
      url = "/getPartialOutput/#{api_key}/#{job_id}/"
      ClientObj.get(url)
    end
    resp
  end

  def self.info
    resp = handle_exceptions do
      url = "/info/#{api_key}/"
      ClientObj.get(url)
    end
    resp["info"]
  end

  def self.jobs(deadjobs = 0)
    resp = handle_exceptions do
      url = "/jobs/#{api_key}/#{deadjobs}/"
      ClientObj.get(url)
    end
    resp["jobs"]
  end

  def self.pool(image = nil)
    resp = handle_exceptions do
      url = image.nil? ? "/pool/#{api_key}/" : "/pool/#{api_key}/#{image}/"
      ClientObj.get(url)
    end
    resp["pools"]
  end

  def self.prealloc(image, num, options = {})
    handle_exceptions do
      url = "/prealloc/#{api_key}/#{image}/#{num}/"
      ClientObj.get(url, body: options)
    end
  end

  def self.build(name, file)
    handle_exceptions do
      url = "/build/#{api_key}/"
      headers = { "Content-Type": "application/octet-stream", "imageName": name }
      ClientObj.post(url, headers: headers, body: file)
    end
  end

  def self.api_key
    RESTFUL_KEY
  end
end
