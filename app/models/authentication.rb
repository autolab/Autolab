##
# Each user has many authentications so that they can sign in with multiple methods
#
class Authentication < ActiveRecord::Base
  belongs_to :user
end
