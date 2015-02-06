class Group < ActiveRecord::Base
  has_many :assessment_user_data
end
