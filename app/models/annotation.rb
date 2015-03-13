class Annotation < ActiveRecord::Base
  belongs_to :submission
  belongs_to :problem

  validates_presence_of :submission_id, :filename
  validates_presence_of :line, :comment

  def as_text
    if value
      if problem
        "#{comment} (#{value}, #{problem.name})"
      else
        "#{comment} (#{value})"
      end
    elsif problem
      "#{comment} (#{problem.name})"
    else
      comment
    end
  end
end
