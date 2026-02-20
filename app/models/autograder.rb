##
# This model has nothing to do with actually autograding assessments, and instead deals
# with autograding properties for an assessment
#
class Autograder < ApplicationRecord
  belongs_to :assessment
  belongs_to :ami_image, optional: true

  # Encryption for AWS credentials
  has_encrypted :access_key
  has_encrypted :access_key_id

  trim_field :autograde_image

  # Validations
  validates :autograde_timeout,
            numericality: { greater_than_or_equal_to: 10, less_than_or_equal_to: 900 }
  validates :autograde_image, :autograde_timeout, presence: true
  validates :autograde_image, length: { maximum: 64 }

  with_options if: :use_access_key do
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
