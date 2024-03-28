class Group < ApplicationRecord
  has_many :assessment_user_data
  has_many :course_user_data, through: :assessment_user_data
  before_destroy :clear_members

  delegate :size, to: :assessment_user_data

  def is_member(aud)
    aud.group_id == id && aud.group_confirmed(AssessmentUserDatum::CONFIRMED)
  end

  def enough_room_for(aud, group_size)
    aud.group_id == id || size < group_size
  end

  # If the only members left in the group are those pending group confirmation,
  # then the group is as good as empty since only confirmed members can potentially add them
  def is_effectively_empty
    assessment_user_data.where(membership_status: [AssessmentUserDatum::GROUP_CONFIRMED,
                                                   AssessmentUserDatum::CONFIRMED]).empty?
  end

private

  def clear_members
    assessment_user_data.each(&:leave_group)
  end
end
