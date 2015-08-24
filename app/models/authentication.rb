##
# Each user has many authentications so that they can sign in with multiple methods
#
class Authentication < ActiveRecord::Base
  belongs_to :user

  validates_uniqueness_of :uid, scope: :provider
end
