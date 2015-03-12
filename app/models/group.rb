class Group < ActiveRecord::Base
  has_many :assessment_user_data
  has_many :course_user_data, through: :assessment_user_data
  
  def size
    assessment_user_data.size
  end
  
  def is_member(aud)
    aud.group_id == self.id && aud.group_confirmed(AssessmentUserDatum::CONFIRMED)
  end
  
  def enough_room_for(aud, group_size)
    aud.group_id == self.id || self.size < group_size
  end
  
end
