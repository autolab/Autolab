class JobsQueueBroadcastJob < ApplicationJob
    queue_as :default
  
    def perform(jobs_queue)
      # broadcast jobs_queue so that all subscribers can have access to the jobs_queue.
      ActionCable.server.broadcast 'assessment_channel', jobs_queue: jobs_queue
    end
  
    private
      def render_jobs_queue(jobs_queue)
        # The controller renderer has been extracted from the controller instance
        # and can now be called as a class method
        ApplicationController.renderer.render(partial: 'jobs_queues/jobs_queue', locals: { jobs_queue: jobs_queue })
      end
  end