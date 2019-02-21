class Scheduler < ApplicationRecord
  trim_field :action
  self.table_name = :scheduler
  belongs_to :course

  validates_numericality_of :interval
  validates_presence_of :action
  validates_associated :course
end
