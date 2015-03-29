##
# Announcements get made by Instructors and Autolab Admins, and get displayed
# to everyone who uses the site, until they expire.
#
class Announcement < ActiveRecord::Base
  belongs_to :course
  trim_field :title
end
