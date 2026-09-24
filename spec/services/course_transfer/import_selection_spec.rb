require "rails_helper"
require "tmpdir"
require Rails.root.join("app/services/course_transfer/core_exporters")
require Rails.root.join("app/services/course_transfer/import_selection")

RSpec.describe CourseTransfer::ImportSelection do
  def reference(table, key)
    { "table" => table.to_s, "key" => key }
  end

  def write_documents(root, name, documents)
    File.open(root.join("#{name}.yml"), "w") do |file|
      documents.each { |document| CourseTransfer::Serialization.dump_document(file, document) }
    end
  end

  it "imports only the selected user/assessment intersection and its dependencies" do
    Dir.mktmpdir("import-selection-spec-") do |directory|
      root = Pathname.new(directory)
      course_key = { "name" => "source-course" }
      selected_user_key = { "email" => "selected@example.com" }
      excluded_user_key = { "email" => "excluded@example.com" }
      selected_cud_key = {
        "course_id" => course_key,
        "user_id" => selected_user_key
      }
      excluded_cud_key = {
        "course_id" => course_key,
        "user_id" => excluded_user_key
      }
      selected_assessment_key = { "course_id" => course_key, "name" => "selected" }
      excluded_assessment_key = { "course_id" => course_key, "name" => "excluded" }
      included_submission_key = {
        "assessment_id" => selected_assessment_key,
        "course_user_datum_id" => selected_cud_key,
        "version" => 1
      }
      wrong_user_submission_key = {
        "assessment_id" => selected_assessment_key,
        "course_user_datum_id" => excluded_cud_key,
        "version" => 1
      }
      wrong_assessment_submission_key = {
        "assessment_id" => excluded_assessment_key,
        "course_user_datum_id" => selected_cud_key,
        "version" => 1
      }

      documents = {
        courses: [{ "_key" => course_key }],
        users: [
          { "_key" => selected_user_key, "email" => "selected@example.com" },
          { "_key" => excluded_user_key, "email" => "excluded@example.com" }
        ],
        course_user_data: [
          {
            "_key" => selected_cud_key,
            "course_id" => reference(:courses, course_key),
            "user_id" => reference(:users, selected_user_key)
          },
          {
            "_key" => excluded_cud_key,
            "course_id" => reference(:courses, course_key),
            "user_id" => reference(:users, excluded_user_key)
          }
        ],
        assessments: [
          {
            "_key" => selected_assessment_key,
            "course_id" => reference(:courses, course_key),
            "name" => "selected"
          },
          {
            "_key" => excluded_assessment_key,
            "course_id" => reference(:courses, course_key),
            "name" => "excluded"
          }
        ],
        submissions: [
          {
            "_key" => included_submission_key,
            "course_user_datum_id" => reference(:course_user_data, selected_cud_key),
            "assessment_id" => reference(:assessments, selected_assessment_key)
          },
          {
            "_key" => wrong_user_submission_key,
            "course_user_datum_id" => reference(:course_user_data, excluded_cud_key),
            "assessment_id" => reference(:assessments, selected_assessment_key)
          },
          {
            "_key" => wrong_assessment_submission_key,
            "course_user_datum_id" => reference(:course_user_data, selected_cud_key),
            "assessment_id" => reference(:assessments, excluded_assessment_key)
          }
        ]
      }

      documents.each { |name, rows| write_documents(root, name, rows) }
      root.join("manifest.yml").write({
        "format" => CourseTransfer::Version::FORMAT_ID,
        "version" => CourseTransfer::Version::CURRENT,
        "min_target_version" => CourseTransfer::Version::MIN_SUPPORTED_TARGET.to_s,
        "parts" => documents.keys.map(&:to_s)
      }.to_yaml)

      context = CourseTransfer::Context.new(
        staging_path: root,
        version: CourseTransfer::Version::CURRENT
      )
      selection = described_class.new(
        registry: CourseTransfer::CoreExporters.registry,
        context:,
        user_keys: [CourseTransfer::Serialization.canonical(selected_user_key)],
        assessment_keys: [CourseTransfer::Serialization.canonical(selected_assessment_key)]
      )

      expect(selection.included_keys.fetch(:users)).to contain_exactly(
        CourseTransfer::Serialization.canonical(selected_user_key)
      )
      expect(selection.included_keys.fetch(:assessments)).to contain_exactly(
        CourseTransfer::Serialization.canonical(selected_assessment_key)
      )
      expect(selection.included_keys.fetch(:submissions)).to contain_exactly(
        CourseTransfer::Serialization.canonical(included_submission_key)
      )
      expect(selection.excluded_user_emails).to eq(["excluded@example.com"])
      expect(selection.excluded_assessment_names).to eq(["excluded"])
    end
  end
end

RSpec.describe CourseTransfer::ImportPreview do
  it "provides stable selection keys and membership roles for the import UI" do
    Dir.mktmpdir("import-preview-spec-") do |directory|
      root = Pathname.new(directory)
      course_key = { "name" => "source-course" }
      user_key = { "email" => "teacher@example.com" }
      assessment_key = { "course_id" => course_key, "name" => "lab" }
      documents = {
        users: [{
          "_key" => user_key,
          "email" => "teacher@example.com",
          "first_name" => "Course",
          "last_name" => "Teacher"
        }],
        course_user_data: [{
          "_key" => { "course_id" => course_key, "user_id" => user_key },
          "user_id" => { "table" => "users", "key" => user_key },
          "instructor" => true,
          "course_assistant" => false
        }],
        assessments: [{
          "_key" => assessment_key,
          "name" => "lab",
          "display_name" => "Lab One"
        }]
      }
      documents.each do |name, rows|
        File.open(root.join("#{name}.yml"), "w") do |file|
          rows.each { |row| CourseTransfer::Serialization.dump_document(file, row) }
        end
      end
      root.join("manifest.yml").write({
        "format" => CourseTransfer::Version::FORMAT_ID,
        "version" => CourseTransfer::Version::CURRENT,
        "min_target_version" => CourseTransfer::Version::MIN_SUPPORTED_TARGET.to_s,
        "parts" => documents.keys.map(&:to_s)
      }.to_yaml)
      context = CourseTransfer::Context.new(
        staging_path: root,
        version: CourseTransfer::Version::CURRENT
      )

      preview = described_class.new(
        registry: CourseTransfer::CoreExporters.registry,
        context:
      )

      expect(preview.users.first.to_h).to include(
        key: CourseTransfer::Serialization.canonical(user_key),
        name: "Course Teacher",
        email: "teacher@example.com",
        role: "Instructor"
      )
      expect(preview.assessments.first.to_h).to include(
        key: CourseTransfer::Serialization.canonical(assessment_key),
        name: "Lab One",
        email: "lab"
      )
    end
  end
end
