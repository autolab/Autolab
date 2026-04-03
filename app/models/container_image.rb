class ContainerImage < ApplicationRecord
  belongs_to :course, optional: true

  enum status: {
    draft: 0,
    building: 1,
    ready: 2,
    failed: 3,
    disabled: 4
  }

  validates :name, presence: true
  validates :image_uri, presence: true, uniqueness: true
  validate :public_or_course_scoped

  # Extract tag from image_uri
  def tag
    return nil unless image_uri.include?(":")

    image_uri.split(":").last
  end

  private

  # Ensure image is either public OR tied to a course
  def public_or_course_scoped
    return if is_public || course_id.present?

    errors.add(:base, "Container image must be public or belong to a course")
  end
end