require "digest"
require "fileutils"
require "find"
require "pathname"
require_relative "errors"
require_relative "file_pool"
require_relative "serialization"

module CourseTransfer
  # Builds and restores the filesystem-shaped portion of a course package.
  class FileTransfer
    COURSE_DIRECTORY = Pathname.new("files/course").freeze
    ATTACHMENTS_DIRECTORY = Pathname.new("files/attachments").freeze

    # @param plan [CourseTransfer::ExportPlan]
    # @param context [CourseTransfer::Context]
    # @param key_maps [Hash]
    # @return [void]
    def self.export(plan, context:, key_maps:)
      new(context:, key_maps:).export(plan)
    end

    # @param context [CourseTransfer::Context]
    # @param imported_ids [Hash{Symbol => Array<Integer>}]
    # @param key_maps [Hash]
    # @return [CourseTransfer::FileTransfer] cleanup handle
    def self.import(context:, imported_ids:, key_maps:)
      transfer = new(context:, key_maps:)
      transfer.import(imported_ids)
      transfer
    rescue StandardError
      transfer&.cleanup!
      raise
    end

    def initialize(context:, key_maps:)
      @root = context.staging_path
      @key_maps = key_maps
      @uploaded_blobs = []
      @restored_course = nil
    end

    # Copies the course tree with unselected assessments and users filtered out.
    # Files are hard-linked into staging when possible and copied otherwise.
    #
    # @param plan [CourseTransfer::ExportPlan]
    # @return [void]
    def export(plan)
      course = plan.relation_for(:courses).first!
      destination = @root.join(COURSE_DIRECTORY)
      FileUtils.mkdir_p(destination)

      assessments = plan.relation_for(:assessments).includes(:course).to_a
      exported_user_ids = plan.relation_for(:users).pluck(:id)
      excluded_emails = course.course_user_data.joins(:user)
                              .where.not(user_id: exported_user_ids)
                              .pluck("users.email")

      FilePool.open do |pool|
        copy_course_root(course, assessments, destination, pool)
        copy_assessments(assessments, exported_user_ids, excluded_emails, destination, pool)
        export_attachments(plan, pool)
      end
    rescue ActiveRecord::ActiveRecordError, SystemCallError => e
      raise FileTransferError, "unable to export course files: #{e.message}"
    end

    # Restores the course tree under the imported identifier and uploads
    # exported attachment files through Active Storage.
    #
    # @param imported_ids [Hash{Symbol => Array<Integer>}]
    # @return [void]
    def import(imported_ids)
      restore_course(imported_ids.fetch(:courses).uniq)
      restore_attachments(imported_ids.fetch(:attachments, []).uniq)
    end

    # Removes external files created by an import whose transaction rolled back.
    #
    # @return [void]
    def cleanup!
      cleanup_each(@uploaded_blobs) { |blob| blob.service.delete(blob.key) }
      FileUtils.rm_rf(@restored_course) if @restored_course
    end

  private

    def copy_course_root(course, assessments, destination, pool)
      excluded = course.assessments.pluck(:name).map { |name| course.directory_path.join(name) }
      excluded << course.directory_path.join("autolab.log")
      copy_tree(course.directory_path, destination, pool:) do |path|
        excluded.any? { |root| within?(path, root) }
      end

      # Selected assessment directories are copied separately with handin filters.
      assessments.each { |assessment| FileUtils.mkdir_p(destination.join(assessment.name)) }
    end

    def copy_assessments(assessments, exported_user_ids, excluded_emails, destination, pool)
      assessment_ids = assessments.map(&:id)
      excluded_paths = excluded_submission_paths(
        assessment_ids, assessments.first&.course_id, exported_user_ids
      )
      excluded_emails = excluded_emails.compact.map(&:downcase).to_set

      assessments.each do |assessment|
        handin = if assessment.handin_directory.present?
                   assessment.handin_directory_path.expand_path
                 end
        copy_tree(assessment.folder_path, destination.join(assessment.name), pool:) do |path|
          excluded_handin_path?(path, handin, excluded_paths, excluded_emails)
        end
      end
    end

    def excluded_submission_paths(assessment_ids, course_id, exported_user_ids)
      return Set.new if assessment_ids.empty?

      unexported_memberships = CourseUserDatum.where(course_id:)
                                              .where.not(user_id: exported_user_ids).select(:id)
      paths = Set.new
      Submission.includes(:assessment, course_user_datum: :user)
                .where(assessment_id: assessment_ids, course_user_datum_id: unexported_memberships)
                .find_each do |submission|
        [submission.handin_file_path, submission.handin_annotated_file_path,
         submission.autograde_feedback_path].compact.each do |path|
          paths << Pathname.new(path).expand_path
        end
      end
      paths
    end

    def excluded_handin_path?(path, handin, excluded_paths, excluded_emails)
      return false unless handin && within?(path, handin) && path != handin
      return true if excluded_paths.include?(path.expand_path)

      relative_parts = path.relative_path_from(handin).each_filename.map(&:downcase)
      return true if relative_parts.any? { |part| excluded_emails.include?(part) }
      return false if path.directory?

      excluded_emails.any? { |email| path.basename.to_s.downcase.include?(email) }
    end

    def copy_tree(source, destination, pool: nil)
      source = Pathname.new(source).expand_path
      return unless source.directory?
      raise FileTransferError, "symbolic links are not exportable: #{source}" if source.symlink?

      Find.find(source.to_s) do |entry|
        path = Pathname.new(entry)
        next if path == source

        if block_given? && yield(path)
          Find.prune if path.directory?
          next
        end

        raise FileTransferError, "symbolic links are not exportable: #{path}" if path.symlink?

        target = destination.join(path.relative_path_from(source))
        if path.directory?
          FileUtils.mkdir_p(target)
        elsif path.file?
          if pool
            pool.post(path, target) { |from, to| link_or_copy(from, to) }
          else
            link_or_copy(path, target)
          end
        else
          raise FileTransferError, "special files are not exportable: #{path}"
        end
      end
    end

    def link_or_copy(source, destination)
      FileUtils.mkdir_p(destination.dirname)
      File.link(source, destination)
    rescue Errno::EXDEV, Errno::EPERM, Errno::EACCES, Errno::EOPNOTSUPP
      FileUtils.copy_file(source, destination)
    end

    def export_attachments(plan, pool)
      return unless plan.include?(:attachments)

      plan.relation_for(:attachments)
          .includes(attachment_file_attachment: :blob).find_each do |attachment|
        key = @key_maps.fetch(:attachments).fetch(attachment.id)
        destination = attachment_path(key, attachment.filename)
        FileUtils.mkdir_p(destination.dirname)

        pool.post(attachment, destination) do |record, target|
          export_attachment(record, target)
        end
      end
    end

    def export_attachment(attachment, destination)
      if attachment.attachment_file.attached?
        File.open(destination, "wb") do |output|
          attachment.attachment_file.blob.download { |chunk| output.write(chunk) }
        end
      else
        fallback = Rails.root.join("attachments", attachment.filename.to_s)
        link_or_copy(fallback, destination) if fallback.file? && !fallback.symlink?
      end
    end

    def restore_course(course_ids)
      raise FileTransferError, "a package must restore exactly one course" unless course_ids.one?

      source = @root.join(COURSE_DIRECTORY)
      raise FileTransferError, "course file payload is missing" unless source.exist?
      raise FileTransferError, "course file payload is not a directory" unless source.directory?

      destination = Course.find(course_ids.first).directory_path
      if destination.exist?
        raise FileTransferError, "course directory already exists: #{destination}"
      end

      FileUtils.mkdir_p(destination.dirname)
      @restored_course = destination
      move_tree(source, destination)
    rescue ActiveRecord::ActiveRecordError, SystemCallError => e
      raise FileTransferError, "unable to restore course files: #{e.message}"
    end

    def move_tree(source, destination)
      File.rename(source, destination)
    rescue Errno::EXDEV
      FileUtils.mkdir_p(destination)
      FilePool.open do |pool|
        copy_tree(source, destination, pool:)
      end
      FileUtils.rm_rf(source)
    end

    def restore_attachments(attachment_ids)
      expected = Set.new
      keys_by_id = @key_maps.fetch(:attachments, {}).to_h { |key, id| [id, key] }
      transfers = Attachment.where(id: attachment_ids).map do |attachment|
        key = keys_by_id.fetch(attachment.id) do
          raise FileTransferError, "missing portable attachment key"
        end
        source = attachment_path(key, attachment.filename)
        next unless source.file? && !source.symlink?

        expected << source.expand_path
        [attachment, source]
      end.compact

      blobs = prepare_attachment_blobs(transfers)
      blobs.each(&:save!)
      @uploaded_blobs.concat(blobs)
      upload_attachment_blobs(transfers, blobs)
      transfers.zip(blobs).each do |(attachment, _source), blob|
        attachment.attachment_file.attach(blob)
      end

      actual = attachment_files
      unknown = actual - expected
      raise FileTransferError, "package contains an unknown attachment file" if unknown.any?
    end

    def prepare_attachment_blobs(transfers)
      blobs = Array.new(transfers.length)
      FilePool.open do |pool|
        transfers.each_with_index do |(attachment, source), index|
          pool.post(attachment, source, index) do |record, path, position|
            blob = ActiveStorage::Blob.new(
              filename: record.filename,
              content_type: record.mime_type
            )
            File.open(path, "rb") { |input| blob.unfurl(input, identify: false) }
            blobs[position] = blob
          end
        end
      end
      blobs
    end

    def upload_attachment_blobs(transfers, blobs)
      FilePool.open do |pool|
        transfers.zip(blobs).each do |(_attachment, source), blob|
          pool.post(source, blob) do |path, uploaded_blob|
            File.open(path, "rb") { |input| uploaded_blob.upload_without_unfurling(input) }
          end
        end
      end
    end

    def attachment_files
      root = @root.join(ATTACHMENTS_DIRECTORY)
      return Set.new unless root.exist?
      raise FileTransferError, "attachment payload is not a directory" unless root.directory?

      root.glob("**/*").select(&:file?).map(&:expand_path).to_set
    end

    def attachment_path(key, filename)
      address = Digest::SHA256.hexdigest(key.is_a?(String) ? key : Serialization.canonical(key))
      @root.join(ATTACHMENTS_DIRECTORY, address, File.basename(filename.to_s))
    end

    def cleanup_each(items)
      items.each do |item|
        yield item
      rescue StandardError => e
        Rails.logger.error("Course transfer cleanup failed: #{e.class}: #{e.message}")
      end
    end

    def within?(path, root)
      path = Pathname.new(path).expand_path.to_s
      root = Pathname.new(root).expand_path.to_s
      path == root || path.start_with?("#{root}#{File::SEPARATOR}")
    end
  end
end
