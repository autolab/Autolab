class Annotation < ActiveRecord::Base
  belongs_to :submission
  belongs_to :problem

  validates_presence_of :submission_id, :filename
  validates_presence_of :line, :comment

  def as_text
    if (self.value) then
      if (self.problem) then
        "#{self.comment} (#{self.value}, #{self.problem.name})"
      else
        "#{self.comment} (#{self.value})"
      end
    elsif (self.problem) then
      "#{self.comment} (#{self.problem.name})"
    else
      self.comment
    end
  end

end
