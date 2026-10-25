module CourseArchive
  class Restore
    def initialize(root, rows)
      @root, @rows = root, rows
      @maps = TABLES.keys.index_with { {} }
      @created, @blobs, @generated, @staff = [], [], [], []
      @group_keys = {}
    end

    def call(identifier:, display_name:, instructor_email:)
      identifier = Paths.identifier!(identifier.to_s.strip)
      raise Error, "Display name and instructor email are required" if
        display_name.to_s.strip.empty? || instructor_email.to_s.strip.empty?

      @directory = Rails.root.join("courses", identifier)
      config = Rails.root.join("courseConfig", "#{identifier.gsub(/[^A-Za-z0-9]/, '')}.rb")
      File.open(Rails.root.join("tmp", "course-import-#{config.basename}.lock"), "a") do |lock|
        raise Error, "Another import is using this course identifier" unless
          lock.flock(File::LOCK_EX | File::LOCK_NB)
        raise Error, "Course identifier or configuration already exists" if
          Course.where("LOWER(name) = ?", identifier.downcase).exists? ||
          @directory.exist? || @directory.symlink? || config.exist? || config.symlink?

        FileUtils.mkdir_p(@directory.dirname)
        Dir.mkdir(@directory)
        @owns_directory = true
        ApplicationRecord.transaction(requires_new: true) do
          TABLES.each do |name, model|
            @rows.fetch(name).each do |row|
              attributes = row.except("_id").symbolize_keys
              model::COURSE_EXPORT_REFERENCES.each do |field, target|
                value = attributes[field]
                if value&.positive?
                  attributes[field] =
                    @maps.fetch(target.to_s).fetch(value)
                end
              end
              adjust(name, attributes, identifier, display_name.to_s.strip)
              id = if name == "users"
                     user_id(attributes)
                   else
                     insert(model, attributes)
                   end
              @maps.fetch(name)[row.fetch("_id")] = id
            end
          end
          course = Course.find(@maps.fetch("courses").values.fetch(0))
          enroll_instructor(course, instructor_email.to_s.strip)
          Content.restore(@root, @rows, course, @maps, @blobs)
          finish(course)
          course
        end
      end
    rescue StandardError, SyntaxError
      cleanup if @owns_directory
      raise
    end

  private

    def adjust(name, attributes, identifier, display_name)
      case name
      when "courses"
        attributes.merge!(name: identifier, display_name:, disabled: true, access_code: nil,
                          cgdub_dependencies_updated_at: Time.current)
        attributes[:late_slack] ||= 0
        attributes[:grace_days] ||= 0
        if attributes[:late_penalty_id].nil? || attributes[:version_penalty_id].nil?
          penalty = Penalty.find_or_create_by!(kind: ScoreAdjustment::POINTS, value: 0)
          attributes[:late_penalty_id] ||= penalty.id
          attributes[:version_penalty_id] ||= penalty.id
        end
      when "assessments"
        attributes[:remote_handin_path] = nil
      when "container_images"
        attributes.merge!(image_uri: nil, status: "draft")
      when "submissions"
        attributes[:jobid] = nil
        key = attributes[:group_key]
        attributes[:group_key] = (@group_keys[key] ||= SecureRandom.uuid) if key.present?
      end
    end

    # One callback-free insert with the adapter's returned ID. Imported history
    # must not trigger live handin callbacks, grading jobs, or notifications.
    def insert(model, attributes)
      connection = model.connection
      columns = attributes.keys.map { |field| connection.quote_column_name(field) }
      values = attributes.map do |field, value|
        connection.quote(model.type_for_attribute(field.to_s).serialize(value))
      end
      # rubocop:disable Rails/SkipsModelValidations
      id = connection.insert("INSERT INTO #{connection.quote_table_name(model.table_name)} " \
                             "(#{columns.join(', ')}) VALUES (#{values.join(', ')})")
      # rubocop:enable Rails/SkipsModelValidations
      @created << [model, id]
      id
    end

    def user_id(attributes)
      Paths.filename!(attributes.fetch(:email))
      existing = User.where("LOWER(email) = ?", attributes.fetch(:email).downcase).pick(:id)
      return existing if existing

      user = User.new(attributes)
      user.password = user.password_confirmation = Devise.friendly_token[0, 20]
      user.skip_confirmation!
      raise Error, user.errors.full_messages.join(", ") unless user.valid?

      insert(User, user.attributes.except("id"))
    end

    def enroll_instructor(course, email)
      id = user_id(email:, first_name: "Instructor", last_name: course.name)
      member = course.course_user_data.find_by(user_id: id)
      if member
        # rubocop:disable Rails/SkipsModelValidations
        member.update_columns(instructor: true, dropped: false)
        # rubocop:enable Rails/SkipsModelValidations
      else
        insert(CourseUserDatum, course_id: course.id, user_id: id, instructor: true, dropped: false)
      end
    end

    def finish(course)
      FileUtils.mkdir_p([Rails.root.join("courseConfig"), Rails.root.join("assessmentConfig")])
      source = course.directory_path.join("course.rb")
      FileUtils.cp(Rails.root.join("lib/__defaultCourse.rb"), source) unless source.file?
      FileUtils.touch(course.directory_path.join("autolab.log"))
      raise Error, "Course configuration already exists" if course.config_file_path.exist?

      @generated << course.config_file_path
      existing = course.assessment_user_data.pluck(:assessment_id, :course_user_datum_id).to_set
      course.assessment_ids.product(course.course_user_datum_ids).each do |assessment, member|
        insert(AssessmentUserDatum, assessment_id: assessment, course_user_datum_id: member) unless
          existing.include?([assessment, member])
      end
      course.assessments.each do |assessment|
        path = assessment.unique_config_file_path
        raise Error, "Assessment configuration already exists" if path.exist? || path.symlink?

        @generated << path
        assessment.construct_folder
        assessment.load_config_file
        assessment.dump_embedded_quiz
      end
      course.attachments.each { |attachment| attachment.send(:initialize_slug) }
      @created.each do |model, id|
        record = model.find(id)
        unless record.valid?
          raise Error,
                "Invalid #{model.name}: #{record.errors.full_messages.join(', ')}"
        end
      end
      course.send(:ensure_unix_group_exists)
      course.send(:ensure_service_user_group_membership!)
      course.course_user_data.where(instructor: true, dropped: false).find_each do |member|
        @staff << [course, member.user]
        member.send(:setup_unix_group_membership)
      end
      course.reload_course_config
      FilesystemEnforcer.fix_tree(course.directory_path.to_s)
    end

    def cleanup
      actions = @blobs.map { |blob| -> { blob.service.delete(blob.key) } } +
                @generated.map { |path| -> { FileUtils.rm_f(path) } } +
                @staff.map do |course, user|
                  -> {
                    UnixGroupManager.update_course_staff_membership(course, user, is_staff: false)
                  }
                end
      actions << -> { FileUtils.rm_rf(@directory) }
      actions.each do |action|
        action.call
      rescue StandardError => e
        Rails.logger.error("Course archive cleanup failed: #{e.message}")
      end
    end
  end
end
