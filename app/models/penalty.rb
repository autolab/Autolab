class Penalty < ScoreAdjustment
  # penalties should always be positive
  validates :value, numericality: { greater_than_or_equal_to: 0 }

  SERIALIZABLE = Set.new %w[kind value]
  def serialize
    Utilities.serializable attributes, SERIALIZABLE
  end

  def self.applied_penalty(penalty, score, multiplier)
    superclass.applied_value(penalty, score, multiplier)
  end
end
