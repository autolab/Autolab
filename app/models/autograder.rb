##
# This model has nothing to do with actually autograding assessments, and instead deals
# with autograding properties for an assessment
#
class Autograder < ApplicationRecord
  belongs_to :assessment

  trim_field :autograde_image

  INSTANCE_TYPES = %w[
    t2.micro t2.small t2.medium t2.large t2.xlarge t2.2xlarge
    t3.micro t3.small t3.medium t3.large
    c5.large c5.xlarge c5.2xlarge
    r5.large r5.xlarge r5.2xlarge
    g4dn.xlarge g4dn.2xlarge g5.xlarge
  ].freeze

  # extremely short timeout values cause the backend to throw system errors
  validates :autograde_timeout,
            numericality: { greater_than_or_equal_to: 10, less_than_or_equal_to: 900 }
  validates :autograde_image, :autograde_timeout, presence: true
  validates :autograde_image, length: { maximum: 64 }

  after_commit -> { assessment.dump_yaml }

  SERIALIZABLE = Set.new %w[autograde_image autograde_timeout release_score]
  def serialize
    Utilities.serializable attributes, SERIALIZABLE
  end
end
