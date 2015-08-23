##
# Annotations are Submission and Problem specific.
# Currently, they are just text, but it would be nice if they could be used in
# score calculations in the future.
#
class Annotation < ActiveRecord::Base
  belongs_to :submission
  belongs_to :problem

  validates :comment, :filename, :submission_id, presence: true

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
