class CreateJobsQueues < ActiveRecord::Migration[5.2]
    def change
      create_table :jobs_queues do |t|
        t.text :running_jobs
        t.text :waiting_jobs
  
        t.timestamps
      end
    end
  end
  