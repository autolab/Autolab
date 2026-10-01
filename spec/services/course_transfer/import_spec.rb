require "rails_helper"
require Rails.root.join("app/services/course_transfer/import")

RSpec.describe CourseTransfer::ImportManager do
  def document_for(name, attributes = {})
    table = CourseTransfer::Schema.fetch(name)
    table.fields.index_with { nil }.transform_keys(&:to_s).merge(
      "_id" => 1,
      **attributes
    )
  end

  def validate_documents(documents)
    indexed = documents.transform_values do |rows|
      rows = [rows] unless rows.is_a?(Array)
      rows.index_by { |document| document.fetch("_id") }
    end
    selection = instance_double(
      CourseTransfer::ImportSelection,
      parts: indexed.keys.to_set,
      documents: indexed
    )
    manager = described_class.new(context: nil)
    manager.instance_variable_set(:@selection, selection)
    manager.send(:validate_package!)
  end

  it "rejects assessment identifiers that can escape the course directory" do
    document = document_for(
      :assessments,
      "name" => "../../outside",
      "handin_directory" => "handin",
      "handin_filename" => "submission.tar"
    )

    expect { validate_documents(assessments: document) }
      .to raise_error(CourseTransfer::InvalidPackage, /assessment name/)
  end

  it "rejects traversal in package-supplied filesystem fields" do
    assessment = document_for(
      :assessments,
      "name" => "lab",
      "handin_directory" => "../../outside",
      "handin_filename" => "submission.tar"
    )
    submission = document_for(:submissions, "filename" => "../submission.tar")

    expect { validate_documents(assessments: assessment) }
      .to raise_error(CourseTransfer::InvalidPackage, /handin directory/)
    expect { validate_documents(submissions: submission) }
      .to raise_error(CourseTransfer::InvalidPackage, /submission filename/)
  end

  it "rejects user identifiers that are unsafe as handin directory components" do
    document = document_for(:users, "email" => "../../outside")

    expect { validate_documents(users: document) }
      .to raise_error(CourseTransfer::InvalidPackage, /user email/)
  end

  it "allows nested annotation paths that remain relative" do
    document = document_for(:annotations, "filename" => "src/models/user.rb")

    expect { validate_documents(annotations: document) }.not_to raise_error
  end
end
