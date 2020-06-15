require "statistics.rb"

module CourseBase
  # For backward compatibility, define courseAverage(user), 
  # but not courseAggregate(user)... 
  def courseAverage(user)
    s = Statistics.new
    s.mean(user.values)
  end

  def gradebookMessage
    ""
  end

  def defaultCategoryAggregate(user)
    final_scores = user.values
    if final_scores.size > 0
      {name: "Average",
       value: final_scores.reduce(:+) / final_scores.size,}

    else
      {name: "Average", value: nil }
    end
  end

end
