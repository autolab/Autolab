class Tweak < ScoreAdjustment
  def self.applied_tweak(tweak, score)
    superclass.applied_value(tweak, score, 1)
  end

  # @param tweak ScoreAdjustment/nil  The tweak to be applied, if any
  # @param score float                The score to be applied on
  #
  # @return The applied adjustment (float)
  def self.apply_tweak(tweak, score)
    raise ArgumentError, "ScoreAdjustment.apply_tweak: score was nil" if score.nil?

    score + applied_tweak(tweak, score)
  end
end
