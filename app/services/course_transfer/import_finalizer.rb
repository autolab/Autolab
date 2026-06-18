require "fileutils"

module CourseTransfer
  # Rebuilds derived state normally produced by callbacks skipped by bulk import.
  class ImportFinalizer
    def initialize(course, imported_ids:)
      @course = course
      @imported_ids = imported_ids
      @generated_files = []
      @staff_memberships = []
    end

    # @return [void]
    def finalize!
      prepare_course
      fill_missing_assessment_users
      prepare_assessments
      initialize_attachment_slugs
      @generated_files << @course.config_file_path unless @course.config_file_path.exist?
      @course.reload_course_config
      FilesystemEnforcer.fix_tree(@course.directory_path.to_s)
    end

    # Best-effort cleanup for external effects when the database rolls back.
    # @return [void]
    def cleanup!
      @generated_files.reverse_each { |path| FileUtils.rm_f(path) }
      @staff_memberships.reverse_each do |datum|
        UnixGroupManager.update_course_staff_membership(
          @course, datum.user, is_staff: false
        )
      rescue StandardError => e
        Rails.logger.error("Course import membership cleanup failed: #{e.message}")
      end
    end

  private

    def prepare_course
      @course.send(:ensure_unix_group_exists)
      @course.send(:ensure_service_user_group_membership!)
      FileUtils.mkdir_p([
                          @course.directory_path,
                          Rails.root.join("courseConfig"),
                          Rails.root.join("assessmentConfig")
                        ])
      create_file(@course.directory_path.join("autolab.log")) { |path| FileUtils.touch(path) }

      @course.course_user_data.where(instructor: true, dropped: false).find_each do |datum|
        datum.send(:setup_unix_group_membership)
        @staff_memberships << datum
      end
    end

    def fill_missing_assessment_users
      assessment_ids = @course.assessment_ids
      datum_ids = @course.course_user_datum_ids
      existing = AssessmentUserDatum.where(
        assessment_id: assessment_ids, course_user_datum_id: datum_ids
      ).pluck(:assessment_id, :course_user_datum_id).to_set

      missing = assessment_ids.product(datum_ids).reject { |pair| existing.include?(pair) }
      return if missing.empty?

      # rubocop:disable Rails/SkipsModelValidations
      AssessmentUserDatum.insert_all!(missing.map do |assessment_id, course_user_datum_id|
        { assessment_id:, course_user_datum_id: }
      end)
      # rubocop:enable Rails/SkipsModelValidations
      missing = missing.to_set
      imported = AssessmentUserDatum.where(
        assessment_id: assessment_ids, course_user_datum_id: datum_ids
      ).pluck(:id, :assessment_id, :course_user_datum_id)
      ids = imported.filter_map do |id, assessment_id, datum_id|
        id if missing.include?([assessment_id, datum_id])
      end
      @imported_ids[:assessment_user_data].concat(ids)
    end

    def prepare_assessments
      @course.assessments.find_each do |assessment|
        generated = [assessment.unique_source_config_file_path,
                     assessment.unique_config_file_path,
                     assessment.asmt_yaml_path]
        generated.each { |path| @generated_files << path unless File.exist?(path) }
        assessment.construct_folder
        assessment.load_config_file
        assessment.dump_embedded_quiz
      end
    end

    def initialize_attachment_slugs
      @course.attachments.where(slug: nil).find_each do |attachment|
        attachment.send(:initialize_slug)
      end
    end

    def create_file(path)
      return if File.exist?(path)

      yield path
      @generated_files << path
    end
  end
end
