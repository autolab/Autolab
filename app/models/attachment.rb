class Attachment < ActiveRecord::Base
  validates_presence_of :name
  validates_presence_of :filename

  belongs_to :course
  belongs_to :assessment

  def file=(upload)
    directory = "attachments"
    filename = File.basename(upload.original_filename)
    path = File.join(Rails.root, directory, filename)
    addendum = 1

    # Deal with duplicate filenames on disk
    while File.exist?(path)
      path = File.join(Rails.root, directory,
                       "#{filename}.#{addendum}")

      addendum += 1
    end
    self.filename = File.basename(path)
    File.open(path, "wb") { |f| f.write(upload.read) }
    self.mime_type = upload.content_type
  end

  def after_create
    COURSE_LOGGER.log("Created Attachment #{id}:#{filename} " \
      "(#{mime_type}) as \"#{name}\")")
  end
end
