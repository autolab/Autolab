require "digest"
require "fileutils"
require "find"
require "pathname"
require_relative "errors"
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

      copy_course_root(course, assessments, destination)
      copy_assessments(assessments, exported_user_ids, excluded_emails, destination)
      export_attachments(plan)
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

    def copy_course_root(course, assessments, destination)
      excluded = course.assessments.pluck(:name).map { |name| course.directory_path.join(name) }
      excluded << course.directory_path.join("autolab.log")
      copy_tree(course.directory_path, destination) do |path|
        excluded.any? { |root| within?(path, root) }
      end

      # Selected assessment directories are copied separately with handin filters.
      assessments.each { |assessment| FileUtils.mkdir_p(destination.join(assessment.name)) }
    end

    def copy_assessments(assessments, exported_user_ids, excluded_emails, destination)
      assessment_ids = assessments.map(&:id)
      excluded_paths = excluded_submission_paths(
        assessment_ids, assessments.first&.course_id, exported_user_ids
      )
      excluded_emails = excluded_emails.compact.map(&:downcase).to_set

      assessments.each do |assessment|
        handin = if assessment.handin_directory.present?
                   assessment.handin_directory_path.expand_path
                 end
        copy_tree(assessment.folder_path, destination.join(assessment.name)) do |path|
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

    def copy_tree(source, destination)
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
          link_or_copy(path, target)
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

    def export_attachments(plan)
      return unless plan.include?(:attachments)

      plan.relation_for(:attachments)
          .includes(attachment_file_attachment: :blob).find_each do |attachment|
        key = @key_maps.fetch(:attachments).fetch(attachment.id)
        destination = attachment_path(key, attachment.filename)
        FileUtils.mkdir_p(destination.dirname)

        if attachment.attachment_file.attached?
          File.open(destination, "wb") do |output|
            attachment.attachment_file.blob.download { |chunk| output.write(chunk) }
          end
        else
          fallback = Rails.root.join("attachments", attachment.filename.to_s)
          link_or_copy(fallback, destination) if fallback.file? && !fallback.symlink?
        end
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
      FileUtils.mv(source, destination)
      @restored_course = destination
    rescue ActiveRecord::ActiveRecordError, SystemCallError => e
      raise FileTransferError, "unable to restore course files: #{e.message}"
    end

    def restore_attachments(attachment_ids)
      expected = Set.new
      keys_by_id = @key_maps.fetch(:attachments, {}).to_h { |key, id| [id, key] }

      Attachment.where(id: attachment_ids).find_each do |attachment|
        key = keys_by_id.fetch(attachment.id) do
          raise FileTransferError, "missing portable attachment key"
        end
        source = attachment_path(key, attachment.filename)
        next unless source.file? && !source.symlink?

        expected << source.expand_path
        File.open(source, "rb") do |input|
          blob = ActiveStorage::Blob.create_and_upload!(
            io: input,
            filename: attachment.filename,
            content_type: attachment.mime_type
          )
          @uploaded_blobs << blob
          attachment.attachment_file.attach(blob)
        end
      end

      actual = attachment_files
      unknown = actual - expected
      raise FileTransferError, "package contains an unknown attachment file" if unknown.any?
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
