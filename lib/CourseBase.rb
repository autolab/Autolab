# frozen_string_literal: true

require "statistics"

module CourseBase
  def courseAverage(user)
    Statistics.mean(user.values)
  end

  def gradebookMessage
    ""
  end
end
