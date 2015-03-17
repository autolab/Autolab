class Penalty < ScoreAdjustment
  # penalties should always be positive
  validates_numericality_of :value, greater_than_or_equal_to: 0

  def self.applied_penalty(penalty, score, multiplier)
    superclass.applied_value(penalty, score, multiplier)
  end
end
