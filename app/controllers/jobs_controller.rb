require "cgi"
require "uri"
require "tango_client"

##
# This controller communicates with Tango to give information about autograding jobs
#
class JobsController < ApplicationController
  autolab_require Rails.root.join("config/autogradeConfig.rb")

  # index - This is the default action that generates lists of the
  # running, waiting, and completed jobs.
  action_auth_level :index, :student
  def index
    # Instance variables that will be used by the view
    @running_jobs = []   # running jobs
    @waiting_jobs = []   # jobs waiting in job queue
    @dead_jobs = []      # dead jobs culled from dead job queue
    @dead_jobs_view = [] # subset of dead jobs to view

    # Get the number of dead jobs the user wants to view
    dead_count = AUTOCONFIG_DEF_DEAD_JOBS
    dead_count = params[:id].to_i if params[:id]
    dead_count = 0 if dead_count < 0
    dead_count = AUTOCONFIG_MAX_DEAD_JOBS if dead_count > AUTOCONFIG_MAX_DEAD_JOBS

    # Get the complete lists of live and dead jobs from the server
    begin
      raw_live_jobs = TangoClient.jobs
      raw_dead_jobs = TangoClient.jobs(1)
    rescue TangoClient::TangoException => e
      flash.now[:error] = "Error while getting job list: #{e.message}"
    end

    # Build formatted lists of the running, waiting, and dead jobs
    return unless raw_live_jobs && raw_dead_jobs

    raw_live_jobs.each do |rjob|
      if rjob["assigned"] == true
        @running_jobs << formatRawJob(rjob, true)
      else
        @waiting_jobs << formatRawJob(rjob, true)
      end
    end

    # Non-admins have a limited view of the completed
    # jobs. Instructors can see only the completed jobs from
    # the current course. Students can see only their own
    # jobs.
    raw_dead_jobs.each do |rjob|
      job = formatRawJob(rjob, false)

      @dead_jobs << job if job[:name] != "*"
    end

    # Sort the list of dead jobs and then trim it for the view
    @dead_jobs.sort! { |a, b| [b[:tlast], b[:id]] <=> [a[:tlast], a[:id]] }
    @dead_jobs_view = @dead_jobs[0, dead_count]
  end

  #
  # getjob - This action generates detailed information about a specific job.
  #
  action_auth_level :getjob, :student
  def getjob
    # Make sure we have a job id parameter
    if !params[:id]
      flash[:error] = "Error: missing job ID parameter in URL"
      redirect_to(controller: "jobs", item: nil) && return
    else
      job_id = params[:id] ? params[:id].to_i : 0
    end

    # Get the complete lists of live and dead jobs from the server
    begin
      raw_live_jobs = TangoClient.jobs
      raw_dead_jobs = TangoClient.jobs(1)
    rescue TangoClient::TangoException => e
      flash[:error] = "Error while getting job list: #{e.message}"
    end

    # Find job job_id in one of those lists
    rjob = nil
    is_live = false
    if raw_live_jobs && raw_dead_jobs
      raw_live_jobs.each do |item|
        next unless item["id"] == job_id

        rjob = item
        is_live = true
        break
      end
      if rjob.nil?
        raw_dead_jobs.each do |item|
          next unless item["id"] == job_id

          rjob = item
          break
        end
      end
    end

    if rjob.nil?
      flash[:error] = "Could not find job #{job_id}"
      redirect_to(controller: "jobs", item: nil) && return
    end

    # Create the job record that will be used by the view
    @job = formatRawJob(rjob, is_live)

    # Try to find the autograder feedback for this submission and
    # assign it to the @feedback_str instance variable for later
    # use by the view
    if rjob["notifyURL"]
      uri = URI(rjob["notifyURL"])

      # Parse the notify URL from the autograder
      path_parts = uri.path.split("/")
      url_course = path_parts[2]
      url_assessment = path_parts[4]

      # create a hash of keys pointing to value arrays
      params = CGI.parse(uri.query)

      # Grab all of the scores for this submission
      begin
        submission = Submission.find(params["submission_id"][0])
      rescue StandardError # submission not found, tar tar sauce!
        return
      end
      scores = submission.scores

      # We don't have any information about which problems were
      # autograded, so search each problem until we find one
      # that has autograder feedback and save it for the view.
      i = 0
      feedback_num = 0
      @feedback_str = ""
      scores.each do |score|
        i += 1
        next unless score.feedback && score.feedback["Autograder"]

        @feedback_str = score.feedback
        feedback_num = i
        break
      end
    end

    # Students see only the output report from the autograder. So
    # bypass the view and redirect them to the viewFeedback page
    return unless !@cud.instructor? && !@cud.user.administrator?

    if url_assessment && submission && feedback_num > 0
      redirect_to(viewFeedback_course_assessment_path(url_course, url_assessment,
                                                      submission_id: submission.id,
                                                      feedback: feedback_num)) && return
    end

    flash[:error] = "Could not locate autograder feedback"
    redirect_to(controller: :jobs, item: nil) && return
  end

  action_auth_level :tango_status, :instructor
  def tango_status
    # Obtain overall Tango info and pool status
    @tango_info = TangoClient.info
    @vm_pool_list = TangoClient.pool
    # Obtain Image -> Course mapping
    @img_to_course = {}
    Assessment.find_each do |asmt|
      if asmt.has_autograder?
        a = asmt.autograder
        @img_to_course[a.autograde_image] ||= Set.new []
        @img_to_course[a.autograde_image] << asmt.course.name
      end
    end
    # Run through job list and extract useful data
    @tango_live_jobs = TangoClient.jobs
    @tango_dead_jobs = TangoClient.jobs(1)
    @plot_data = tango_plot_data(@tango_live_jobs, @tango_dead_jobs)
    # Get a list of current and upcoming assessments
    @upcoming_asmt = []
    Assessment.find_each do |asmt|
      @upcoming_asmt << asmt if asmt.has_autograder? && asmt.due_at > Time.current
    end
    @upcoming_asmt.sort! { |a, b| a.due_at <=> b.due_at }
  end

  action_auth_level :tango_data, :instructor
  def tango_data
    @data = tango_plot_data
    render(json: @data) && return
  end

protected

  # formatRawJob - Given a raw job from the server, creates a job
  # hash for the view.
  def formatRawJob(rjob, is_live)
    job = {}
    job[:rjob] = rjob
    job[:id] = rjob["id"]
    job[:name] = rjob["name"]

    if rjob["notifyURL"]
      uri = URI(rjob["notifyURL"])
      path_parts = uri.path.split("/")
      job[:course] = path_parts[2]
      job[:assessment] = path_parts[4]
    end

    # Determine whether to expose the job name.
    unless @cud.user.administrator?
      if !@cud.instructor?
        # Students can see only their own job names
        job[:name] = "*" unless job[:name].ends_with? "_#{@cud.user.email}"
      elsif !rjob["notifyURL"] || !(job[:course].eql? @cud.course.id.to_s)
        job[:name] = "*"
      end
      # Instructors can see only their course's job names
    end

    # Extract timestamps of first and last trace records
    if rjob["trace"]
      job[:first] = rjob["trace"][0].split("|")[0]
      job[:last] = rjob["trace"][-1].split("|")[0]

      # Compute elapsed time. Live jobs show time from submission
      # until now.  Dead jobs show end-to-end elapsed time.
      t1 = DateTime.parse(job[:first]).to_time
      if is_live
        snow = Time.now.in_time_zone.to_s
        t2 = DateTime.parse(snow).to_time
      else
        t2 = DateTime.parse(job[:last]).to_time
      end
      job[:elapsed] = t2.to_i - t1.to_i # elapsed seconds
      job[:tlast] = t2.to_i             # epoch time when the job completed

      # Get status and overall summary of the job's state
      job[:status] = rjob["trace"][-1].split("|")[1]
    end

    if is_live
      job[:state] = if job[:status]["Added job"]
                      "Waiting"
                    else
                      "Running"
                    end
    else
      job[:state] = "Completed"
      job[:state] = "Failed" if rjob["trace"][-1].split("|")[1].include? "Error"
    end

    job
  end

  def tango_plot_data(live_jobs = nil, dead_jobs = nil)
    live_jobs ||= TangoClient.jobs
    dead_jobs ||= TangoClient.jobs(1)
    @plot_data = { new_jobs: { name: "New Job Requests", dates: [], job_name: [], job_id: [],
                               vm_pool: [], vm_id: [], status: [], duration: [] },
                   job_errors: { name: "Job Errors", dates: [], job_name: [], job_id: [],
                                 vm_pool: [], vm_id: [], retry_count: [], duration: [] },
                   failed_jobs: { name: "Job Failures", dates: [], job_name: [], job_id: [],
                                  vm_pool: [], vm_id: [], duration: [] } }
    live_jobs.each do |j|
      next if j["trace"].nil? || j["trace"].empty?

      tstamp = j["trace"][0].split("|")[0]
      name = j["name"]
      pool = j["vm"]["name"]
      vmid = j["vm"]["id"]
      jid = j["id"]
      status = j["assigned"] ? "Running (assigned)" : "Waiting to be assigned"
      trace = j["trace"].join
      duration = Time.parse(j["trace"].last.split("|")[0]).to_i -
                 Time.parse(j["trace"].first.split("|")[0]).to_i

      if j["retries"] > 0 || trace.include?("fail") || trace.include?("error")
        status = "Running (error occured)"
        j["trace"].each do |tr|
          next unless tr.include?("fail") || tr.include?("error")

          @plot_data[:job_errors][:dates] << tr.split("|")[0]
          @plot_data[:job_errors][:job_name] << name
          @plot_data[:job_errors][:vm_pool] << pool
          @plot_data[:job_errors][:vm_id] << vmid
          @plot_data[:job_errors][:retry_count] << j["retries"]
          @plot_data[:job_errors][:duration] << duration
          @plot_data[:job_errors][:job_id] << jid
        end
      end
      @plot_data[:new_jobs][:dates] << tstamp
      @plot_data[:new_jobs][:job_name] << name
      @plot_data[:new_jobs][:vm_pool] << pool
      @plot_data[:new_jobs][:vm_id] << vmid
      @plot_data[:new_jobs][:status] << status
      @plot_data[:new_jobs][:duration] << duration
      @plot_data[:new_jobs][:job_id] << jid
    end
    dead_jobs.each do |j|
      next if j["trace"].nil? || j["trace"].empty?

      tstamp = j["trace"][0].split("|")[0]
      name = j["name"]
      jid = j["id"]
      pool = j["vm"]["name"]
      vmid = j["vm"]["id"]
      trace = j["trace"].join
      duration = Time.parse(j["trace"].
                      last.split("|")[0]).to_i -
                 Time.parse(j["trace"].
                 first.split("|")[0]).to_i

      warnings = false
      if j["retries"] > 0 || trace.include?("fail") || trace.include?("error")
        j["trace"].each do |tr|
          next unless tr.include?("fail") || tr.include?("error")

          @plot_data[:job_errors][:dates] << tr.split("|")[0]
          @plot_data[:job_errors][:job_name] << name
          @plot_data[:job_errors][:vm_pool] << pool
          @plot_data[:job_errors][:vm_id] << vmid
          @plot_data[:job_errors][:retry_count] << j["retries"]
          @plot_data[:job_errors][:duration] << duration
          @plot_data[:job_errors][:job_id] << jid
        end
        warnings = true
      end
      if !j["trace"][-1].include?("Autodriver returned normally")
        status = "Errored"
        @plot_data[:failed_jobs][:dates] << tstamp
        @plot_data[:failed_jobs][:job_name] << name
        @plot_data[:failed_jobs][:vm_pool] << pool
        @plot_data[:failed_jobs][:vm_id] << vmid
        @plot_data[:failed_jobs][:duration] << duration
        @plot_data[:failed_jobs][:job_id] << jid
      else
        status = warnings ? "Completed with errors" : "Completed"
      end
      @plot_data[:new_jobs][:dates] << tstamp
      @plot_data[:new_jobs][:job_name] << name
      @plot_data[:new_jobs][:vm_pool] << pool
      @plot_data[:new_jobs][:vm_id] << vmid
      @plot_data[:new_jobs][:status] << status
      @plot_data[:new_jobs][:duration] << duration
      @plot_data[:new_jobs][:job_id] << jid
    end
    @plot_data = @plot_data.values
  end
end
