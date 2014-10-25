 $:.unshift("/usr/share/tango2/thrift/gen-rb/")

require 'autoConfig'
require "ModuleBase.rb"

class JobsController < ApplicationController
  include ModuleBase
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
    if params[:id] then
      dead_count = params[:id].to_i
    end
    if dead_count < 0 then
      dead_count = 0
    end
    if dead_count > AUTOCONFIG_MAX_DEAD_JOBS then
      dead_count = AUTOCONFIG_MAX_DEAD_JOBS
    end

    # Get the complete lists of live and dead jobs from the server
    raw_live_jobs = getCurrentJobs()
    raw_dead_jobs = getDeadJobs()

    # Build formatted lists of the running, waiting, and dead jobs
    if raw_live_jobs and raw_dead_jobs then
      for rjob in raw_live_jobs do
        if rjob["assigned"] == true then
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

        if job[:name] != "*" then
          @dead_jobs << job
        end
      end

      # Sort the list of dead jobs and then trim it for the view
      @dead_jobs.sort! {|a,b| [b[:tlast],b[:id]] <=> [a[:tlast],a[:id]] }
      @dead_jobs_view = @dead_jobs[0, dead_count]

    end
  end

  #
  # getjob - This action generates detailed information about a specific job.
  #
  action_auth_level :getjob, :student
  def getjob
    # Make sure we have a job id parameter
    if not params[:id] then 
      flash[:error] = "Error: missing job ID parameter in URL"
      redirect_to :controller=>"jobs", :item=>nil and return
    else
      job_id = params[:id] ? params[:id].to_i : 0
    end

    # Get the complete lists of live and dead jobs from the server
    raw_live_jobs = getCurrentJobs()
    raw_dead_jobs = getDeadJobs()

    # Find job job_id in one of those lists
    rjob = nil
    is_live = false
    if raw_live_jobs and raw_dead_jobs then
      for item in raw_live_jobs do
        if item[:id] == job_id then
          rjob = item
          is_live = true
          break
        end
      end
      if not rjob then
        for item in raw_dead_jobs do
          if item["id"] == job_id then
            rjob = item
            break
          end
        end
      end
    end

    if rjob == nil then
      flash[:error] = "Could not find job #{job_id}"
      redirect_to :controller=>"jobs", :item=>nil and return
    end
    
    # Create the job record that will be used by the view
    @job = formatRawJob(rjob, is_live)
   
    # Try to find the autograder feedback for this submission and
    # assign it to the @feedback_str instance variable for later
    # use by the view
    if rjob["notifyURL"] then 

      # Parse the notify URL from the autograder
      params =  rjob["notifyURL"].split('/')
      url_submission = params[-2]
      url_assessment = params[-4]
      url_course = params[-6]
   
      # Grab all of the scores for this submission
      scores = Score.where(:submission_id=>url_submission)

      # We don't have any information about which problems were
      # autograded, so search each problem until we find one
      # that has autograder feedback and save it for the view.
      i = 0
      feedback_num = 0
      @feedback_str = ""
      for score in scores do
        i += 1
        if score.feedback != nil and score.feedback["Autograder"] then
          @feedback_str = score.feedback
          feedback_num = i
          break
        end
      end
    end

    # Students see only the output report from the autograder. So
    # bypass the view and redirect them to the viewFeedback page
    if !@cud.user.administrator? and !@cud.instructor? then
      if url_assessment and url_submission and feedback_num > 0 then
        redirect_to :controller=>url_assessment, :action=>"viewFeedback", 
        :submission=>url_submission, :feedback=>feedback_num and return 
      else 
        flash[:error] = "Could not locate autograder feedback"
        redirect_to :controller=>"jobs", :item=>nil and return
      end
    end
  end

  protected

  # formatRawJob - Given a raw job from the server, creates a job
  # hash for the view.
  def formatRawJob(rjob, is_live) 

    job = Hash.new
    job[:rjob] = rjob
    job[:id] = rjob["id"]
    job[:name] = rjob["name"]

    # Determine whether to expose the job name (which contains an AndrewID).
    if !@cud.user.administrator?  then
      if !@cud.instructor? then 
        # Students can see only their own job names
        if !job[:name][@cud.user.email] then
          job[:name] = "*"
        end
      else
        # Instructors can see only their course's job names
        if !rjob["notifyURL"] then
          job[:name] = "*"
        end
      end
    end

    # Extract timestamps of first and last trace records    
    if rjob["trace"] then
      job[:first] = rjob["trace"][0].split("|")[0] 
      job[:last] = rjob["trace"][-1].split("|")[0] 
    
      # Compute elapsed time. Live jobs show time from submission
      # until now.  Dead jobs show end-to-end elapsed time.
      t1 = DateTime.parse(job[:first]).to_time
      if is_live then
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

    if is_live then
      if job[:status]["Added job"] then
        job[:state] = "Waiting"
      else
        job[:state] = "Running"
      end
    else
      job[:state] = "Completed"
    end

    return job
  end

end



