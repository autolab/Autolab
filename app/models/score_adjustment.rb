class ScoreAdjustment < ActiveRecord::Base
  # attr_accessible :kind, :value

  validates_presence_of :value, :kind
  validates_numericality_of :value
 
  # constants for the kind of score_adjustment
  POINTS=0
  PERCENT=1

  # @param adj        ScoreAdjustment/nil   The adjustment to be applied, if any
  # @param score      float                 The score to be applied on
  # @param multiplier +ve int               Number of times to apply the adjustment
  #
  # @return The applied adjustment (float)
  def self.applied_value(adj, score, multiplier)
    if score.nil?
      raise ArgumentError.new("ScoreAdjustment.applied_value: score was nil")
    elsif adj.nil?
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
      write_attribute(:kind, POINTS)
    when "percent"
      write_attribute(:kind, PERCENT) 
    else
      raise ArgumentError
    end
  end

  def kind
    case read_attribute(:kind)
    when POINTS
      "points"
    when PERCENT
      "percent"
    end
  end

  def to_s
    case read_attribute(:kind)
    when POINTS
      type_str = "points"
    when PERCENT    
      type_str = "%"
    else
      raise ArgumentError
    end

    sprintf("%+g", value) + " " + type_str
  end
end
