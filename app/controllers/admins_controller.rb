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
    # Obtain overall Tango info
    @tango_info = TangoClient.info
    # Obtain Tango VM Pools
    @vm_pool_list = [ { :pool_name => "rhel.img", :image_name => "rhel.img" },
                      { :pool_name => "rhel10601.img", :image_name => "rhel10601.img" },
                      { :pool_name => "rhel210.img", :image_name => "rhel210.img" }
                    ]
    # Obtain VM status for each pool
    @vm_pool_list.each{ |p|
        hash = TangoClient.pool(p[:pool_name])
        p[:vm_list] = hash["total"].sort!
        p[:free_vm_list] = hash["free"].sort!
        p[:free_vm_rate] = hash["free"].length.to_f / hash["total"].length * 100
    }
    # Run through job list and extract useful data
    @tango_live_jobs = TangoClient.jobs
    @tango_dead_jobs = TangoClient.jobs(deadjobs = 1)
    @plot_data = { new_jobs: { name: "New Job Requests", dates: [], job_name: [],
                                     vm_image: [], vm_id: [], status: [] },
                   job_errors: { name: "Job Errors", dates: [], job_name: [],
                                     vm_image: [], vm_id: [], retry_count: [] },
                   failed_jobs: { name: "Job Failures", dates: [], job_name: [],
                                  vm_image: [], vm_id: [] } }
    @tango_live_jobs.each{ |j|
        next if j["trace"].nil? || j["trace"].length == 0
        tstamp = j["trace"][0].split("|")[0]
        name = j["name"]
        image = j["vm"]["image"]
        vmid = j["vm"]["id"]
        status = j["assigned"] ? "#6699ff" : "#006699" # Assigned => pale blue; otherwise deep blue.
        trace = j["trace"].join
        if j["retries"] > 0 || trace.include?("fail") || trace.include?("error") then
            status = "#660099" # If errors occured, color is purple.
            j["trace"].each{ |tr|
                next unless tr.include?("fail") || tr.include?("error")
                @plot_data[:job_errors][:dates] << tr.split("|")[0]
                @plot_data[:job_errors][:job_name] << name
                @plot_data[:job_errors][:vm_image] << image
                @plot_data[:job_errors][:vm_id] << vmid
                @plot_data[:job_errors][:retry_count] << j["retries"]
            }
        end
        @plot_data[:new_jobs][:dates] << tstamp
        @plot_data[:new_jobs][:job_name] << name
        @plot_data[:new_jobs][:vm_image] << image
        @plot_data[:new_jobs][:vm_id] << vmid
        @plot_data[:new_jobs][:status] << status
    }
    @tango_dead_jobs.each{ |j|
        next if j["trace"].nil? || j["trace"].length == 0
        tstamp = j["trace"][0].split("|")[0]
        name = j["name"]
        image = j["vm"]["image"]
        vmid = j["vm"]["id"]
        trace = j["trace"].join
        warnings = false
        if j["retries"] > 0 || trace.include?("fail") || trace.include?("error") then
            j["trace"].each{ |tr|
                next unless tr.include?("fail") || tr.include?("error")
                @plot_data[:job_errors][:dates] << tr.split("|")[0] 
                @plot_data[:job_errors][:job_name] << name
                @plot_data[:job_errors][:vm_image] << image
                @plot_data[:job_errors][:vm_id] << vmid
                @plot_data[:job_errors][:retry_count] << j["retries"]
            }
            warnings = true
        end
        if !j["trace"][-1].include?("Autodriver returned normally") then
            status = "#ff0000" # If job fails, color is red.
            @plot_data[:failed_jobs][:dates] << tstamp 
            @plot_data[:failed_jobs][:job_name] << name
            @plot_data[:failed_jobs][:vm_image] << image
            @plot_data[:failed_jobs][:vm_id] << vmid 
        else
            status = warnings ? "#ff6600" : "#195905" # If job completes with warning, color is orange.
        end
        @plot_data[:new_jobs][:dates] << tstamp
        @plot_data[:new_jobs][:job_name] << name
        @plot_data[:new_jobs][:vm_image] << image
        @plot_data[:new_jobs][:vm_id] << vmid
        @plot_data[:new_jobs][:status] << status
    }
    @plot_start = @plot_data[:new_jobs][:dates].min { |a,b| DateTime.parse(a) <=> DateTime.parse(b) }
    @plot_data = @plot_data.values
  end
end
