class JobsQueue < ApplicationRecord
  after_create_commit { JobsQueueBroadcastJob.perform_later(self) }
end
