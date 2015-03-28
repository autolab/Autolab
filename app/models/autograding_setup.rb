##
# This class keeps information about an assessment's autograding properties,
# include the image used and the timeout length
class AutogradingSetup < ActiveRecord::Base
  belongs_to :assessment

  trim_field :autograde_image

  validates :autograde_timeout, numericality: true
  validates :autograde_timeout, presence: true
  validates :autograde_image, length: { maximum: 64 }
  validates :autograde_image, presence: true
  validate :valid_timeout

  # extremely short timeout values cause the backend to throw system errors
  def valid_timeout
    return if autograde_timeout.blank?
    errors.add :autograde_timeout, "must be at least 10 seconds" if autograde_timeout < 10
    errors.add :autograde_timeout, "must be at most 600 seconds" if autograde_timeout > 600
  end

  SERIALIZABLE = Set.new %w(autograde_image autograde_timeout release_score)
  def serialize
    Utilities.serializable attributes, SERIALIZABLE
  end

  def self.deserialize(s)
    new s
  end
end
