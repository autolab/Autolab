##
# This model has nothing to do with actually autograding assessments, and instead deals
# with autograding properties for an assessment
#
class Autograder < ApplicationRecord
  belongs_to :assessment

  encrypts :access_key
  encrypts :access_key_id

  INSTANCE_TYPES = %w[
    t2.nano t2.micro t2.small t2.medium t2.large t2.xlarge t2.2xlarge
    t3.micro t3.small t3.medium t3.large
    c5.large c5.xlarge c5.2xlarge
    r5.large r5.xlarge r5.2xlarge
    g4dn.xlarge g4dn.2xlarge g5.xlarge
  ].freeze

  trim_field :autograde_image

  # Validations
  validates :autograde_timeout,
            numericality: { greater_than_or_equal_to: 10, less_than_or_equal_to: 900 }
  validates :autograde_timeout, inclusion: { in: 10..900 }
  validates :autograde_image, :autograde_timeout, presence: true
  validates :autograde_image, length: { maximum: 512 }
  validates :instance_type, inclusion: { in: INSTANCE_TYPES }, allow_blank: true

  with_options if: :use_access_key? do
    validates :access_key_id, presence: true, format: {
      with: /\A[A-Z0-9]{16,24}\z/,
      message: "looks invalid"
    }
    validates :access_key, presence: true
  end

  after_commit -> { assessment.dump_yaml }

  SERIALIZABLE = Set.new %w[autograde_image autograde_timeout release_score]
  def serialize
    Utilities.serializable attributes, SERIALIZABLE
  end
end
