class ContainerImage < ApplicationRecord
  attr_accessor :dockerfile

  belongs_to :course, optional: true
  belongs_to :public_template,
             class_name: "ContainerImage",
             optional: true
  has_many :derived_images,
           class_name: "ContainerImage",
           foreign_key: :public_template_id,
           dependent: :nullify

  enum status: {
    failed: 255,
    draft: 0,
    building: 1,
    ready: 2,
    disabled: 3
  }

  validates :name, presence: true
  validates :image_uri, uniqueness: true, allow_nil: true
  validate :public_or_course_scoped
  validates :name,
            uniqueness: {
              conditions: -> { where(is_public: true) }
            },
            if: :is_public?

  # Extract tag from image_uri
  def tag
    return nil unless image_uri.include?(":")

    image_uri.split(":").last
  end

  def not_ready
    status == 0 || status == 1
  end

  private

  # Ensure image is either public OR tied to a course
  def public_or_course_scoped
    return if is_public || course_id.present?

    errors.add(:base, "Container image must be public or belong to a course")
  end
end