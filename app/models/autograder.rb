##
# This model has nothing to do with actually autograding assessments, and instead deals
# with autograding properties for an assessment
#
class Autograder < ActiveRecord::Base
  belongs_to :assessment

  trim_field :autograde_image

  # extremely short timeout values cause the backend to throw system errors
  validates :autograde_timeout, numericality: { greater_than: 10, less_than: 600 }
  validates :autograde_image, :autograde_timeout, presence: true
  validates :autograde_image, length: { maximum: 64 }

  SERIALIZABLE = Set.new %w(autograde_image autograde_timeout release_score)
  def serialize
    Utilities.serializable attributes, SERIALIZABLE
  end

  def self.deserialize(s)
    new s
  end
end
