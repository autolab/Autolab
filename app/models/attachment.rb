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
    directory = "attachments"
    filename = File.basename(upload.original_filename)
    dir_path = Rails.root.join(directory)
    FileUtils.mkdir_p(dir_path) unless File.exist?(dir_path)

    path = Rails.root.join(directory, filename)
    addendum = 1

    # Deal with duplicate filenames on disk
    while File.exist?(path)
      path = Rails.root.join(directory, "#{filename}.#{addendum}")
      addendum += 1
    end
    self.filename = File.basename(path)
    File.open(path, "wb") { |f| f.write(upload.read) }
    self.mime_type = upload.content_type
  end

  def after_create
    COURSE_LOGGER.log("Created Attachment #{id}:#{filename} (#{mime_type}) as \"#{name}\")")
  end
end
