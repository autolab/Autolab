class ContainerImage < ApplicationRecord
  COURSE_EXPORT_FIELDS = %i[
    name status image_uri dockerfile_contents created_at updated_at
  ].freeze
  # Building course images on top of a public template image is disabled for
  # now: course export/import can't carry the base image to another AWS
  # account. Set to true to bring the option back.
  TEMPLATES_ENABLED = false

  COURSE_EXPORT_REFERENCES = {
    course_id: :courses
  }.freeze

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

  # Record a finished Tango build. Autograders store the image URI as a plain
  # string, so after a course import they still point at the source course's
  # image. When this course's rebuilt image of the same name becomes ready,
  # move those autograders onto it.
  def mark_built!(uri)
    transaction do
      update!(image_uri: uri)
      relink_orphaned_autograders!
    end
  end

  # Autograders in this course whose URI belongs to no image this course owns
  # (and no public image), and whose tag is this image's name. Tango tags course
  # images "<lowercased name>-<unix time>".
  def relink_orphaned_autograders!
    return if course_id.blank? || image_uri.blank?

    known_uris = ContainerImage.where(course_id:).or(ContainerImage.where(is_public: true))
                               .where.not(image_uri: nil).pluck(:image_uri)
    tag_pattern = /\A#{Regexp.escape(name.downcase)}(-\d+)?\z/
    Autograder.joins(:assessment).where(assessments: { course_id: })
              .where.not(autograde_image: known_uris).find_each do |autograder|
      next unless autograder.autograde_image.to_s.split(":").last.to_s.downcase.match?(tag_pattern)

      autograder.update!(autograde_image: image_uri)
    end
  end

private

  # Ensure image is either public OR tied to a course
  def public_or_course_scoped
    return if is_public || course_id.present?

    errors.add(:base, "Container image must be public or belong to a course")
  end
end
