require "fileutils"

##
# Attachments are Course or Assessment specific, and allow instructors to
# handout files to students through Autolab.
#
class Attachment < ApplicationRecord
  validates :name, presence: true
  validates :category_name, presence: true
  validates :filename, presence: true
  validates :release_at, presence: true
  has_one_attached :attachment_file

  belongs_to :course
  belongs_to :assessment

  # Constants
  ORDERING = "release_at ASC, name ASC".freeze

  # Scopes
  scope :ordered, -> { order(ORDERING) }
  scope :from_category, ->(category_name) { where(category_name: category_name) }
  scope :released, -> { where("release_at <= ?", Time.current) }

  def has_assessment?
    !assessment.nil?
  end

  def released?
    release_at <= Time.current
  end

  def file=(upload)
    self.filename = File.basename(upload.original_filename)
    attachment_file.attach(upload)
  end

  def after_create
    COURSE_LOGGER.log("Created Attachment #{id}:#{filename} (#{mime_type}) as \"#{name}\")")
  end
end
