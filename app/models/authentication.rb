# frozen_string_literal: true

##
# Each user has many authentications so that they can sign in with multiple methods
#
class Authentication < ApplicationRecord
  belongs_to :user
end
