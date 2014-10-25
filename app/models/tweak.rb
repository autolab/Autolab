class Tweak < ScoreAdjustment
  def self.applied_tweak(tweak, score)
    self.superclass.applied_value(tweak, score, 1)
  end

  # @param tweak ScoreAdjustment/nil  The tweak to be applied, if any
  # @param score float                The score to be applied on
  #
  # @return The applied adjustment (float)
  def self.apply_tweak(tweak, score)
    if score.nil?
      raise ArgumentError.new("ScoreAdjustment.apply_tweak: score was nil")
    else
      score + self.applied_tweak(tweak, score)
    end
  end
end
