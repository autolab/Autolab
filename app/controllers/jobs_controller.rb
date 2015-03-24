require "cgi"
require "uri"
require "tango_client"

class JobsController < ApplicationController
  autolab_require Rails.root.join("config", "autogradeConfig.rb")

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
    if params[:id]
      dead_count = params[:id].to_i
    end
    if dead_count < 0
      dead_count = 0
    end
    if dead_count > AUTOCONFIG_MAX_DEAD_JOBS
      dead_count = AUTOCONFIG_MAX_DEAD_JOBS
    end

    # Get the complete lists of live and dead jobs from the server
    begin
      raw_live_jobs = TangoClient.tango_jobs()["jobs"]
      raw_dead_jobs = TangoClient.tango_jobs(deadjobs=1)["jobs"]
    rescue TangoClient::TangoException => e
      flash[:error] = "Error while getting job list: #{e.message}"
    end

    # Build formatted lists of the running, waiting, and dead jobs
    if raw_live_jobs && raw_dead_jobs
      for rjob in raw_live_jobs do
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
      for rjob in raw_dead_jobs do
        job = formatRawJob(rjob, false)

        if job[:name] != "*"
          @dead_jobs << job
        end
      end

      # Sort the list of dead jobs and then trim it for the view
      @dead_jobs.sort! { |a, b| [b[:tlast], b[:id]] <=> [a[:tlast], a[:id]] }
      @dead_jobs_view = @dead_jobs[0, dead_count]

    end
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
      raw_live_jobs = TangoClient.tango_jobs()["jobs"]
      raw_dead_jobs = TangoClient.tango_jobs(deadjobs=1)["jobs"]
    rescue TangoClient::TangoException => e
      flash[:error] = "Error while getting job list: #{e.message}"
    end

    # Find job job_id in one of those lists
    rjob = nil
    is_live = false
    if raw_live_jobs && raw_dead_jobs
      for item in raw_live_jobs do
        if item["id"] == job_id
          rjob = item
          is_live = true
          break
        end
      end
      if rjob.nil?
        for item in raw_dead_jobs do
          if item["id"] == job_id
            rjob = item
            break
          end
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
      path_parts =  uri.path.split("/")
      url_course = path_parts[2]
      url_assessment = path_parts[4]

      # create a hash of keys pointing to value arrays
      params = CGI.parse(uri.query)

      # Grab all of the scores for this submission
      begin
        submission = Submission.find(params["submission_id"][0])
      rescue # submission not found, tar tar sauce!
        return
      end
      scores = submission.scores

      # We don't have any information about which problems were
      # autograded, so search each problem until we find one
      # that has autograder feedback and save it for the view.
      i = 0
      feedback_num = 0
      @feedback_str = ""
      for score in scores do
        i += 1
        if !score.feedback.nil? && score.feedback["Autograder"]
          @feedback_str = score.feedback
          feedback_num = i
          break
        end
      end
    end

    # Students see only the output report from the autograder. So
    # bypass the view and redirect them to the viewFeedback page
    if !@cud.user.administrator? && !@cud.instructor?
      if url_assessment && submission && feedback_num > 0
        redirect_to viewFeedback_course_assessment_path(url_course.to_i, url_assessment.to_i,
                                                        submission_id: submission.id,
                                                        feedback: feedback_num) && return
      else
        flash[:error] = "Could not locate autograder feedback"
        redirect_to(controller: "jobs", item: nil) && return
      end
    end
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
        unless job[:name][@cud.user.email]
          job[:name] = "*"
        end
      else
        # Instructors can see only their course's job names
        if !rjob["notifyURL"] || !(job[:course].eql? @cud.course.id.to_s)
          job[:name] = "*"
        end
      end
    end

    # Extract timestamps of first and last trace records
    if rjob["trace"]
      job[:first] = rjob["trace"][0].split("|")[0]
      job[:last] = rjob["trace"][-1].split("|")[0]

      # Compute elapsed time. Live jobs show time from submission
      # until now.  Dead jobs show end-to-end elapsed time.
      t1 = DateTime.parse(job[:first]).to_time
      if is_live
        snow = Time.now.localtime.to_s
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
      if job[:status]["Added job"]
        job[:state] = "Waiting"
      else
        job[:state] = "Running"
      end
    else
      job[:state] = "Completed"
      if rjob["trace"][-1].split("|")[1].include? "Error"
        job[:state] = "Failed"
      end
    end

    job
  end
end
