require "fileutils"

##
# Attachments are Course or Assessment specific, and allow instructors to
# handout files to students through Autolab.
#
class Attachment < ApplicationRecord
  validates :name, presence: true
  validates :filename, presence: true
  has_one_attached :attachment_file

  belongs_to :course
  belongs_to :assessment

  def file=(upload)
    self.filename = File.basename(upload.original_filename)
    attachment_file.attach(upload)
    self.mime_type = upload.content_type
  end

  def after_create
    COURSE_LOGGER.log("Created Attachment #{id}:#{filename} (#{mime_type}) as \"#{name}\")")
  end
end
