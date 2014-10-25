require 'Statistics.rb'

module CourseBase

  def courseAverage(user)
    Statistics.mean(user.values)
  end

  def gradebookMessage()
    ""
  end
end
