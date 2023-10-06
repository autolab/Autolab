class ScoreAdjustment < ApplicationRecord
  # attr_accessible :kind, :value

  validates :value, :kind, presence: true
  validates :value, numericality: true

  # constants for the kind of score_adjustment
  POINTS = 0
  PERCENT = 1

  # @param adj        ScoreAdjustment/nil   The adjustment to be applied, if any
  # @param score      float                 The score to be applied on
  # @param multiplier +ve int               Number of times to apply the adjustment
  #
  # @return The applied adjustment (float)
  def self.applied_value(adj, score, multiplier)
    raise ArgumentError, "ScoreAdjustment.applied_value: score was nil" if score.nil?

    if adj.nil?
      0.0
    else
      case adj.read_attribute(:kind)
      when POINTS
        multiplier * adj.value
      when PERCENT
        # applying % adjustments to -ve scores makes no semantic sense
        # e.g.: +10% adjustment to -100 points is -110 points
        if score < 0
          0.0
        else
          score * multiplier * (adj.value / 100)
        end
      else
        raise ArgumentError
      end
    end
  end

  def kind=(kind)
    case kind
    when "points"
      self[:kind] = POINTS
    when "percent"
      self[:kind] = PERCENT
    # these two cases are for deserialization
    when POINTS
      self[:kind] = POINTS
    when PERCENT
      self[:kind] = PERCENT
    else
      raise ArgumentError
    end
  end

  def kind
    case self[:kind]
    when POINTS
      "points"
    when PERCENT
      "percent"
    end
  end

  def to_s
    case self[:kind]
    when POINTS
      type_str = " points"
    when PERCENT
      type_str = "%"
    else
      raise ArgumentError
    end

    "#{format('%g', value)}#{type_str}"
  end
end
