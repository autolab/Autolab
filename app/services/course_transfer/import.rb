require "pathname"
require "tango_client"
require_relative "errors"
require_relative "file_transfer"
require_relative "import_finalizer"
require_relative "import_selection"
require_relative "schema"

module CourseTransfer
  class ImportManager
    SAFE_IDENTIFIER = /\A[A-Za-z][A-Za-z0-9_-]*\z/

    attr_reader :context

    def initialize(context:, user_ids: nil, assessment_ids: nil)
      @context = context
      @user_ids = user_ids
      @assessment_ids = assessment_ids
    end

    def import
      @selection = ImportSelection.new(
        context:, user_ids: @user_ids, assessment_ids: @assessment_ids
      )
      validate_package!
      @course_identifier = destination_course_identifier
      @imported_ids = Hash.new { |hash, name| hash[name] = [] }
      cleanup = nil
      finalizer = nil

      # wrapping everything in a transaction allows everything to be rolled back if deemed necessary
      course = ApplicationRecord.transaction(requires_new: true) do
        id_maps = Hash.new { |hash, name| hash[name] = {} }
        Schema.each { |table| import_table(table, id_maps) if @selection.parts.include?(table.name) }

        course = imported_course(id_maps)
        ensure_import_instructor(course) if context.instructor_email.present?
        cleanup = FileTransfer.import(
          context:, imported_ids: @imported_ids, id_maps:, selection: @selection
        )
        validate_import
        finalizer = ImportFinalizer.new(course, imported_ids: @imported_ids)
        finalizer.finalize!
        course
      end
      rebuild_container_images(course)
      course
    rescue StandardError
      finalizer&.cleanup!
      cleanup&.cleanup!
      raise
    end

  private

    def rebuild_container_images(course)
      return unless Rails.configuration.x.ec2_docker == true

      @imported_ids.fetch(:container_images, []).each do |image_id|
        image = ContainerImage.find(image_id)
        image.update!(status: :draft)

        unless image.dockerfile_contents.present?
          image.update!(status: :failed)
          Rails.logger.error(
            "Course import could not rebuild container image #{image.id}: " \
              "Dockerfile contents are missing"
          )
          next
        end

        response = TangoClient.build_image(
          image.name,
          image.id,
          image.dockerfile_contents,
          course.name,
          nil,
          nil
        )
        image.update!(status: response.fetch("status"))
      rescue ActiveRecord::RecordNotFound, ActiveRecord::ActiveRecordError => e
        Rails.logger.error("Course import failed to rebuild container image #{image_id}: #{e.message}")
      rescue TangoClient::TangoException => e
        image&.update!(status: :failed)
        Rails.logger.error("Course import failed to submit container image #{image_id}: #{e.message}")
      end
    end

    def import_table(table, id_maps)
      expected_id = 0
      @selection.documents.fetch(table.name).each_value do |document|
        validate_document!(table, document)
        package_id = document.fetch("_id")
        expected_id += 1
        if package_id != expected_id
          raise InvalidPackage,
                "#{table.filename} expected _id #{expected_id}, got #{package_id.inspect}"
        end
        next unless @selection.include?(table.name, document)

        attributes = table.fields.to_h do |field|
          value = document.fetch(field.to_s)
          # Version 1 packages may contain a source-host handin destination.
          value = nil if table.name == :assessments && field == :remote_handin_path
          if table.ref_fields.key?(field)
            missing = table.missing_reference?(field)
            value = resolve_reference(
              table.ref_fields.fetch(field),
              value,
              id_maps,
              missing:,
              missing_value: missing ? table.missing_reference_value(field) : nil
            )
          end
          [field, value]
        end
        attributes[:name] = @course_identifier if table.name == :courses
        if table.name == :courses && attributes[:cgdub_dependencies_updated_at].nil?
          attributes[:cgdub_dependencies_updated_at] = Time.current
        end
        database_match = table.match_fields.index_with { |field| attributes.fetch(field) }
        database_id, inserted = insert_or_reuse(table, attributes, database_match)
        id_maps[table.name][package_id] = database_id
        @imported_ids[table.name] << database_id if inserted
      end
    rescue ActiveRecord::ActiveRecordError => e
      raise ImportError, "failed to import #{table.name}: #{e.message}"
    end

    def insert_or_reuse(table, attributes, database_match)
      reusable = case table.name
                 when :users
                   User.where("LOWER(email) = ?", attributes.fetch(:email).downcase).pick(:id)
                 when :score_adjustments
                   ScoreAdjustment.find_by(database_match)&.id
                 end
      return [reusable, false] if reusable

      if table.model_class.exists?(database_match)
        raise ImportCollision, "#{table.name} already contains #{database_match.inspect}"
      end

      # Callbacks are intentionally skipped; ImportFinalizer rebuilds derived state once.
      # rubocop:disable Rails/SkipsModelValidations
      table.model_class.insert_all!([attributes])
      # rubocop:enable Rails/SkipsModelValidations
      inserted = table.model_class.where(database_match).pick(table.model_class.primary_key)
      raise ImportError, "could not find imported #{table.name} record" unless inserted

      [inserted, true]
    end

    def validate_document!(table, document)
      unless document.is_a?(Hash)
        raise InvalidPackage, "#{table.filename} contains a non-object row"
      end

      expected = ["_id", *table.fields.map(&:to_s)]
      unknown = document.keys - expected
      missing = expected - document.keys
      raise InvalidPackage, "#{table.filename} contains unknown fields: #{unknown.join(', ')}" if
        unknown.any?
      raise InvalidPackage, "#{table.filename} is missing fields: #{missing.join(', ')}" if
        missing.any?

      package_id = document.fetch("_id")
      return if package_id.is_a?(Integer) && package_id.positive?

      raise InvalidPackage, "#{table.filename} contains an invalid _id"
    end

    def resolve_reference(expected_table, value, id_maps, missing: false, missing_value: nil)
      return nil if value.nil?
      return value if value.is_a?(Numeric) && value <= 0

      valid = value.is_a?(Hash) && value["table"].to_s == expected_table.to_s &&
              value["id"].is_a?(Integer) && value["id"].positive?
      raise InvalidPackage, "invalid reference to #{expected_table}" unless valid

      resolved = id_maps.fetch(expected_table, {})[value.fetch("id")]
      return missing_value if resolved.nil? && missing
      return resolved unless resolved.nil?

      raise MissingImportReference,
            "reference to missing #{expected_table} ID #{value.fetch('id').inspect}"
    end

    def validate_package!
      @selection.parts.each do |name|
        table = Schema.fetch(name)
        @selection.documents.fetch(name).each_value do |document|
          validate_document!(table, document)
        end
      end
      validate_package_paths!
    end

    def validate_package_paths!
      documents_for(:users).each do |document|
        validate_path_component!(document["email"], "user email")
      end
      documents_for(:assessments).each do |document|
        name = document["name"].to_s
        unless SAFE_IDENTIFIER.match?(name)
          raise InvalidPackage, "assessment name #{name.inspect} is not a safe identifier"
        end

        validate_relative_path!(document["handin_directory"], "assessment handin directory")
        validate_filename!(document["handin_filename"], "assessment handin filename")
        %w[handout writeup].each do |field|
          value = document[field]
          next if value.blank? || Utilities.is_url?(value)

          validate_relative_path!(value, "assessment #{field}")
        end
      end
      documents_for(:submissions).each do |document|
        validate_filename!(document["filename"], "submission filename")
      end
      documents_for(:attachments).each do |document|
        validate_filename!(document["filename"], "attachment filename")
      end
      documents_for(:annotations).each do |document|
        validate_relative_path!(document["filename"], "annotation filename")
      end
    end

    def documents_for(name)
      @selection.documents.fetch(name, {}).values
    end

    def validate_path_component!(value, description)
      return if value.blank?

      raw = value.to_s
      if raw.match?(/[[:cntrl:]]/) || raw.include?("/") || raw.include?("\\") ||
         %w[. ..].include?(raw)
        raise InvalidPackage, "#{description} #{raw.inspect} is not a safe path component"
      end
    end

    def validate_filename!(value, description)
      return if value.blank?

      validate_path_component!(value, description)
    end

    def validate_relative_path!(value, description)
      return if value.blank?

      raw = value.to_s
      path = Pathname.new(raw)
      parts = raw.split("/")
      if raw.match?(/[[:cntrl:]]/) || raw.include?("\\") || path.absolute? ||
         parts.include?("..")
        raise InvalidPackage, "#{description} #{raw.inspect} is not a safe relative path"
      end
    end

    def validate_import
      errors = @imported_ids.flat_map do |name, ids|
        table = Schema.fetch(name)
        table.model_class.where(id: ids.uniq).filter_map do |record|
          "#{name} #{record.id}: #{record.errors.full_messages.join(', ')}" unless record.valid?
        end
      end
      raise ImportValidationError, errors.first(20).join("; ") if errors.any?
    end

    def imported_course(id_maps)
      ids = id_maps.fetch(:courses).values.uniq
      raise InvalidPackage, "a package must contain exactly one course" unless ids.one?

      Course.find(ids.first)
    end

    def destination_course_identifier
      documents = @selection.documents.fetch(:courses).values
      unless documents.one? && documents.first["name"].present?
        raise InvalidPackage, "a package must contain exactly one named course"
      end

      identifier = context.course_identifier.presence || documents.first.fetch("name")
      unless identifier.match?(/\A(\w|-)+\z/)
        raise InvalidCourseIdentifier,
              "course identifier may contain only letters, numbers, underscores, and hyphens"
      end
      if Course.where("LOWER(name) = ?", identifier.downcase).exists?
        raise InvalidCourseIdentifier, "course identifier #{identifier.inspect} already exists"
      end

      identifier
    end

    def ensure_import_instructor(course)
      email = context.instructor_email
      user = User.where("LOWER(email) = ?", email.downcase).first
      unless user
        user = User.new(email:, first_name: "Instructor", last_name: course.name)
        User.assign_random_password(user)
        user.save!
        @imported_ids[:users] << user.id
      end

      cud = CourseUserDatum.find_or_initialize_by(course_id: course.id, user_id: user.id)
      cud.assign_attributes(instructor: true, dropped: false)
      # rubocop:disable Rails/SkipsModelValidations
      if cud.new_record?
        CourseUserDatum.insert_all!([cud.attributes.except("id")])
        cud = CourseUserDatum.find_by!(course_id: course.id, user_id: user.id)
      else
        CourseUserDatum.where(id: cud.id).update_all(instructor: true, dropped: false)
      end
      # rubocop:enable Rails/SkipsModelValidations
      @imported_ids[:course_user_data] << cud.id
    rescue ActiveRecord::ActiveRecordError => e
      raise ImportError, "failed to create import instructor: #{e.message}"
    end

  end
end
