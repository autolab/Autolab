require "statistics.rb"

module CourseBase
  def courseAverage(user)
    Statistics.mean(user.values)
  end

  def gradebookMessage
    ""
  end
end
