class AssessmentChannel < ApplicationCable::Channel
    def subscribed
      stream_from "assessment_channel"
    end
  
    def unsubscribed
      # Any cleanup needed when channel is unsubscribed
    end
  
    def self.speak(running_jobs, waiting_jobs)
      JobsQueue.create! running_jobs: running_jobs, waiting_jobs: waiting_jobs
    end
  end
