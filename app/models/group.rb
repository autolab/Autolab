class Group < ApplicationRecord
  has_many :assessment_user_data
  has_many :course_user_data, through: :assessment_user_data
  before_destroy :clear_members

  delegate :size, to: :assessment_user_data

  # User requested to join group but has not been confirmed by the group
  def is_pending_member(aud)
    aud.group_id == id && aud.group_confirmed(AssessmentUserDatum::MEMBER_CONFIRMED) &&
      !aud.group_confirmed(AssessmentUserDatum::CONFIRMED)
  end

  def is_member(aud)
    aud.group_id == id && aud.group_confirmed(AssessmentUserDatum::CONFIRMED)
  end

  def enough_room_for(aud, group_size)
    aud.group_id == id || size < group_size
  end

  def no_confirmed_members
    assessment_user_data.where(membership_status: AssessmentUserDatum::CONFIRMED).empty?
  end

private

  def clear_members
    assessment_user_data.each(&:clear_group)
  end
end
