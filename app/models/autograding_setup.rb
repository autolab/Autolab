class AutogradingSetup < ActiveRecord::Base
  belongs_to :assessment

  trim_field :autograde_image

  validates_numericality_of :autograde_timeout
  validates_presence_of :autograde_timeout
  validates_presence_of :autograde_image
  validates_length_of :autograde_image,  maximum: 64
  validate :valid_timeout

  # extremely short timeout values cause the backend to throw system errors
  def valid_timeout
    unless autograde_timeout.blank?
      errors.add :autograde_timeout, "must be at least 10 seconds" if autograde_timeout < 10
      errors.add :autograde_timeout, "must be at most 600 seconds" if autograde_timeout > 600
    end
  end

  SERIALIZABLE = Set.new %w(autograde_image autograde_timeout release_score)
  def serialize
    Utilities.serializable attributes, SERIALIZABLE
  end

  def self.deserialize(s)
    new s
  end
end
