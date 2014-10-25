class Announcement < ActiveRecord::Base
  belongs_to :course
  trim_field :title
end
