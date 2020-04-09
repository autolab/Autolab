class Extension < ApplicationRecord
  belongs_to :assessment
  belongs_to :course_user_datum
  validates_presence_of :course_user_datum_id
  validate :days_or_infinite
  validates_uniqueness_of :course_user_datum_id, scope: :assessment_id,
                                                 message: "already has an extension."

  after_save :invalidate_cgdubs_for_assessments_after
  after_destroy :invalidate_cgdubs_for_assessments_after

  def days_or_infinite
    if days.blank? && !infinite?
      errors.add(:base, "Please enter days of extension, or mark as infinite.")
    end
  end

  def invalidate_cgdubs_for_assessments_after
    assessment.aud_for(course_user_datum_id).invalidate_cgdubs_for_assessments_after
  end

  def after_create
    if self.infinite?
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
