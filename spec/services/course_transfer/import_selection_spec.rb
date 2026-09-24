require "rails_helper"
require "tmpdir"
require Rails.root.join("app/services/course_transfer/core_exporters")
require Rails.root.join("app/services/course_transfer/import_selection")

RSpec.describe CourseTransfer::ImportSelection do
  def reference(table, id)
    { "table" => table.to_s, "id" => id }
  end

  def write_documents(root, name, documents)
    File.open(root.join("#{name}.yml"), "w") do |file|
      documents.each { |document| CourseTransfer::Serialization.dump_document(file, document) }
    end
  end

  it "imports only the selected user/assessment intersection and its dependencies" do
    Dir.mktmpdir("import-selection-spec-") do |directory|
      root = Pathname.new(directory)
      documents = {
        courses: [{ "_id" => 1 }],
        users: [
          { "_id" => 1, "email" => "selected@example.com" },
          { "_id" => 2, "email" => "excluded@example.com" }
        ],
        course_user_data: [
          {
            "_id" => 1,
            "course_id" => reference(:courses, 1),
            "user_id" => reference(:users, 1)
          },
          {
            "_id" => 2,
            "course_id" => reference(:courses, 1),
            "user_id" => reference(:users, 2)
          }
        ],
        assessments: [
          {
            "_id" => 1,
            "course_id" => reference(:courses, 1),
            "name" => "selected"
          },
          {
            "_id" => 2,
            "course_id" => reference(:courses, 1),
            "name" => "excluded"
          }
        ],
        submissions: [
          {
            "_id" => 1,
            "course_user_datum_id" => reference(:course_user_data, 1),
            "assessment_id" => reference(:assessments, 1)
          },
          {
            "_id" => 2,
            "course_user_datum_id" => reference(:course_user_data, 2),
            "assessment_id" => reference(:assessments, 1)
          },
          {
            "_id" => 3,
            "course_user_datum_id" => reference(:course_user_data, 1),
            "assessment_id" => reference(:assessments, 2)
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
        user_ids: ["1"],
        assessment_ids: ["1"]
      )

      expect(selection.included_ids.fetch(:users)).to contain_exactly(1)
      expect(selection.included_ids.fetch(:assessments)).to contain_exactly(1)
      expect(selection.included_ids.fetch(:submissions)).to contain_exactly(1)
      expect(selection.excluded_user_emails).to eq(["excluded@example.com"])
      expect(selection.excluded_assessment_names).to eq(["excluded"])
    end
  end
end

RSpec.describe CourseTransfer::ImportPreview do
  it "provides stable selection keys and membership roles for the import UI" do
    Dir.mktmpdir("import-preview-spec-") do |directory|
      root = Pathname.new(directory)
      documents = {
        users: [{
          "_id" => 1,
          "email" => "teacher@example.com",
          "first_name" => "Course",
          "last_name" => "Teacher"
        }],
        course_user_data: [{
          "_id" => 1,
          "user_id" => { "table" => "users", "id" => 1 },
          "instructor" => true,
          "course_assistant" => false
        }],
        assessments: [{
          "_id" => 1,
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
        id: "1",
        name: "Course Teacher",
        email: "teacher@example.com",
        role: "Instructor"
      )
      expect(preview.assessments.first.to_h).to include(
        id: "1",
        name: "Lab One",
        email: "lab"
      )
    end
  end
end
