class Group < ActiveRecord::Base
  has_many :assessment_user_data
  has_many :course_user_data, through: :assessment_user_data
end
