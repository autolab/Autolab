class Group < ApplicationRecord
  has_many :assessment_user_data
  has_many :course_user_data, through: :assessment_user_data

  delegate :size, to: :assessment_user_data

  def is_member(aud)
    aud.group_id == id && aud.group_confirmed(AssessmentUserDatum::CONFIRMED)
  end

  def enough_room_for(aud, group_size)
    aud.group_id == id || size < group_size
  end
end
