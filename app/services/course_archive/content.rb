require "digest"

module CourseArchive
  module Content
    def self.copy_tree(source, destination, skip: [], rename: {})
      return unless source.exist?

      Paths.export_source!(source)
      return unless source.directory?

      FileUtils.mkdir_p(destination)
      Find.find(source.to_s) do |entry|
        path = Pathname.new(entry)
        next if path == source

        relative = path.relative_path_from(source).to_s
        if skip.any? { |name| relative == name || relative.start_with?("#{name}/") }
          Find.prune if path.directory?
          next
        end
        next unless path.exist?

        Paths.export_source!(path)

        target = destination.join(path.directory? ? relative : rename.fetch(relative, relative))
        path.directory? ? FileUtils.mkdir_p(target) : FileUtils.copy_file(path, target)
      end
    end

    def self.copy_file(source, destination)
      source = Pathname.new(source) if source
      return if source.nil? || !source.exist?

      Paths.export_source!(source)
      raise Error, "Only regular files can be copied: #{source}" unless source.file?

      FileUtils.mkdir_p(destination.dirname)
      FileUtils.copy_file(source, destination)
    end

    def self.export(root, course, rows)
      timestamp = Time.current.utc.strftime("%Y%m%dT%H%M%S_%6NZ")
      shared = root.join("files/course")
      FileUtils.mkdir_p(shared)
      copy_tree(course.directory_path, shared,
                skip: course.assessments.pluck(:name),
                rename: { "autolab.log" => "autolab_as_of_#{timestamp}.log" })
      users = rows.fetch("users")
      Assessment.where(id: rows.fetch("assessments").pluck("_id")).find_each do |assessment|
        skip = [assessment.handin_directory.presence, "#{assessment.name}.yml"]
               .compact.map { |path| Pathname.new(path).cleanpath.to_s }
        copy_tree(assessment.folder_path, root.join("files/assessments", assessment.id.to_s),
                  skip:, rename: { "log.txt" => "log_as_of_#{timestamp}.txt" })
        next if assessment.handin_directory.blank?

        users.each do |user|
          copy_tree(assessment.handin_directory_path.join(user.fetch("email")),
                    root.join("files/handins", assessment.id.to_s, user.fetch("_id").to_s))
        end
      end
      # Old flat handin layouts are resolved by the model and saved in the same
      # user-owned directory layout as newer submissions.
      Submission.includes(:assessment, course_user_datum: :user)
                .where(id: rows.fetch("submissions").pluck("_id")).find_each do |submission|
        next if submission.filename.blank?

        directory = root.join("files/handins", submission.assessment_id.to_s,
                              submission.course_user_datum.user_id.to_s)
        copy_file(submission.handin_file_path, directory.join(submission.filename))
        copy_file(submission.handin_annotated_file_path,
                  directory.join("annotated_#{submission.filename}"))
        copy_file(submission.autograde_feedback_path,
                  directory.join(submission.autograde_feedback_filename))
      end
      Attachment.where(id: rows.fetch("attachments").pluck("_id")).find_each do |attachment|
        target = root.join("files/attachments", attachment.id.to_s, attachment.filename)
        FileUtils.mkdir_p(target.dirname)
        if attachment.attachment_file.attached?
          File.open(target, "wb") do |output|
            attachment.attachment_file.blob.download { |chunk| output.write(chunk) }
          end
        else
          copy_file(Rails.root.join("attachments", attachment.filename), target)
        end
      rescue ActiveStorage::FileNotFoundError, Errno::ENOENT
        FileUtils.rm_f(target)
      end
    end

    def self.restore(root, rows, course, maps, blobs)
      shared = root.join("files/course")
      raise Error, "Course files are missing" unless shared.directory?

      copy_tree(shared, course.directory_path)
      rows.fetch("assessments").each do |row|
        assessment = Assessment.find(maps.fetch("assessments").fetch(row.fetch("_id")))
        copy_tree(root.join("files/assessments", row.fetch("_id").to_s), assessment.folder_path)
        next if assessment.handin_directory.blank?

        rows.fetch("users").each do |user|
          email = User.find(maps.fetch("users").fetch(user.fetch("_id"))).email
          copy_tree(root.join("files/handins", row.fetch("_id").to_s, user.fetch("_id").to_s),
                    assessment.handin_directory_path.join(email))
        end
      end
      rows.fetch("attachments").each do |row|
        source = root.join("files/attachments", row.fetch("_id").to_s, row.fetch("filename"))
        next unless source.file?

        blob = ActiveStorage::Blob.create_before_direct_upload!(
          filename: row.fetch("filename"), content_type: row["mime_type"],
          byte_size: source.size, checksum: Digest::MD5.file(source).base64digest
        )
        blobs << blob
        File.open(source, "rb") { |input|
          blob.service.upload(blob.key, input, checksum: blob.checksum)
        }
        attachment = Attachment.find(maps.fetch("attachments").fetch(row.fetch("_id")))
        attachment.attachment_file.attach(blob)
      end
      # Resolve whole-handin annotations after copying files: the model chooses
      # the actual destination path, including normalized legacy handin layouts.
      rows.fetch("annotations").each do |row|
        next unless row["filename"].nil?

        annotation = Annotation.find(maps.fetch("annotations").fetch(row.fetch("_id")))
        # rubocop:disable Rails/SkipsModelValidations
        annotation.update_columns(filename: annotation.submission.handin_file_path)
        # rubocop:enable Rails/SkipsModelValidations
      end
    end
  end
end
