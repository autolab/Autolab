class Extension < ApplicationRecord
  belongs_to :assessment
  belongs_to :course_user_datum
  validates :course_user_datum_id, presence: true
  validate :days_or_infinite
  validates :course_user_datum_id, uniqueness: { scope: :assessment_id,
                                                 message: "already has an extension." }

  after_save :invalidate_cgdubs_for_assessments_after
  after_destroy :invalidate_cgdubs_for_assessments_after

  def days_or_infinite
    return unless (days.blank? || days < 0) && !infinite?

    errors.add(:base, "Please enter (≥ 0) days of extension, or mark as infinite.")
  end

  def invalidate_cgdubs_for_assessments_after
    assessment.aud_for(course_user_datum_id).invalidate_cgdubs_for_assessments_after
  end

  def after_create
    if infinite?
      COURSE_LOGGER.log("Extension #{id}: CREATED for " \
      "#{course_user_datum.user.email} on" \
      " #{assessment.name} for unlimited days")
    else
      COURSE_LOGGER.log("Extension #{id}: CREATED for " \
      "#{course_user_datum.user.email} on" \
      " #{assessment.name} for #{days} days")
    end
  end

  def after_destroy
    COURSE_LOGGER.log("Extension #{id}: DESTROYED for " \
    "#{course_user_datum.user.email} on" \
      " #{assessment.name}")
  end
end
