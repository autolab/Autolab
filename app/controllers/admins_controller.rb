##
# this controller contains methods for system-wise
# admin functionality
require "tango_client"

class AdminsController < ApplicationController
  action_auth_level :show, :administrator
  def show
  end

  action_auth_level :email_instructors, :administrator
  def email_instructors
    return unless request.post?

    @cuds = CourseUserDatum.select(:user_id).distinct.joins(:course)
            .where("courses.end_date > ? and instructor = 1", DateTime.now)

    @email = CourseMailer.system_announcement(
      params[:from],
      make_dlist(@cuds),
      params[:subject],
      params[:body])
    @email.deliver
  end

  action_auth_level :tango_status, :administrator
  def tango_status
    # Obtain overall Tango info and pool status
    @tango_info = TangoClient.info
    @vm_pool_list = TangoClient.pool
    # Obtain Image -> Course mapping
    @img_to_course = { }
    Assessment.all.each { |asmt|
        if asmt.has_autograder? then
            a = asmt.autograder
            @img_to_course[a.autograde_image] ||= Set.new []
            @img_to_course[a.autograde_image] << asmt.course.name
        end
    }
    # Run through job list and extract useful data
    @tango_live_jobs = TangoClient.jobs
    @tango_dead_jobs = TangoClient.jobs(deadjobs = 1)
    @plot_data = { new_jobs: { name: "New Job Requests", dates: [], job_name: [], job_id: [],
                                     vm_image: [], vm_id: [], status: [], duration: [] },
                   job_errors: { name: "Job Errors", dates: [], job_name: [], job_id: [],
                                     vm_image: [], vm_id: [], retry_count: [], duration: [] },
                   failed_jobs: { name: "Job Failures", dates: [], job_name: [], job_id: [],
                                  vm_image: [], vm_id: [], duration: [] } }
    @tango_live_jobs.each{ |j|
        next if j["trace"].nil? || j["trace"].length == 0
        tstamp = j["trace"][0].split("|")[0]
        name = j["name"]
        image = j["vm"]["image"]
        vmid = j["vm"]["id"]
        jid = j["id"]
        status = j["assigned"] ? "Running (assigned)" : "Waiting to be assigned"
        trace = j["trace"].join
        duration = Time.parse(j["trace"].last.split("|")[0]).to_i \
                       - Time.parse(j["trace"].first.split("|")[0]).to_i
        if j["retries"] > 0 || trace.include?("fail") || trace.include?("error") then
            status = "Running (error occured)"
            j["trace"].each{ |tr|
                next unless tr.include?("fail") || tr.include?("error")
                @plot_data[:job_errors][:dates] << tr.split("|")[0]
                @plot_data[:job_errors][:job_name] << name
                @plot_data[:job_errors][:vm_image] << image
                @plot_data[:job_errors][:vm_id] << vmid
                @plot_data[:job_errors][:retry_count] << j["retries"]
                @plot_data[:job_errors][:duration] << duration
                @plot_data[:job_errors][:job_id] << jid
            }
        end
        @plot_data[:new_jobs][:dates] << tstamp
        @plot_data[:new_jobs][:job_name] << name
        @plot_data[:new_jobs][:vm_image] << image
        @plot_data[:new_jobs][:vm_id] << vmid
        @plot_data[:new_jobs][:status] << status
        @plot_data[:new_jobs][:duration] << duration
        @plot_data[:new_jobs][:job_id] << jid
    }
    @tango_dead_jobs.each{ |j|
        next if j["trace"].nil? || j["trace"].length == 0
        tstamp = j["trace"][0].split("|")[0]
        name = j["name"]
        jid = j["id"]
        image = j["vm"]["image"]
        vmid = j["vm"]["id"]
        trace = j["trace"].join
        duration = Time.parse(j["trace"].last.split("|")[0]).to_i \
            - Time.parse(j["trace"].first.split("|")[0]).to_i
        warnings = false
        if j["retries"] > 0 || trace.include?("fail") || trace.include?("error") then
            j["trace"].each{ |tr|
                next unless tr.include?("fail") || tr.include?("error")
                @plot_data[:job_errors][:dates] << tr.split("|")[0] 
                @plot_data[:job_errors][:job_name] << name
                @plot_data[:job_errors][:vm_image] << image
                @plot_data[:job_errors][:vm_id] << vmid
                @plot_data[:job_errors][:retry_count] << j["retries"]
                @plot_data[:job_errors][:duration] << duration
                @plot_data[:job_errors][:job_id] << jid
            }
            warnings = true
        end
        if !j["trace"][-1].include?("Autodriver returned normally") then
            status = "Errored"
            @plot_data[:failed_jobs][:dates] << tstamp 
            @plot_data[:failed_jobs][:job_name] << name
            @plot_data[:failed_jobs][:vm_image] << image
            @plot_data[:failed_jobs][:vm_id] << vmid
            @plot_data[:failed_jobs][:duration] << duration
            @plot_data[:failed_jobs][:job_id] << jid
        else
            status = warnings ? "Completed with errors" : "Completed"
        end
        @plot_data[:new_jobs][:dates] << tstamp
        @plot_data[:new_jobs][:job_name] << name
        @plot_data[:new_jobs][:vm_image] << image
        @plot_data[:new_jobs][:vm_id] << vmid
        @plot_data[:new_jobs][:status] << status
        @plot_data[:new_jobs][:duration] << duration
        @plot_data[:new_jobs][:job_id] << jid
    }
    @plot_start = @plot_data[:new_jobs][:dates].min { |a,b| DateTime.parse(a) <=> DateTime.parse(b) }
    @plot_data = @plot_data.values
  end
end
