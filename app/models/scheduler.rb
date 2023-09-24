class Scheduler < ApplicationRecord
  trim_field :action
  self.table_name = :scheduler
  belongs_to :course

  validates :interval, numericality: true
  validates :action, presence: true
  validates_associated :course

  def status
    return "disabled" if disabled
    return "stopped" if Time.current > self.until

    "running"
  end
end
