require "rails_helper"
require Rails.root.join("app/services/course_archive")

RSpec.describe "Course archive container images" do
  # rubocop:disable Rails/SkipsModelValidations
  def record(model, **attributes)
    %w[created_at updated_at].each do |field|
      attributes[field.to_sym] ||= Time.current if model.column_names.include?(field)
    end
    model.insert_all!([attributes])
    model.find_by!(attributes)
  end
  # rubocop:enable Rails/SkipsModelValidations

  let(:registry) { "123.dkr.ecr.us-east-1.amazonaws.com" }
  let(:old_uri) { "#{registry}/source-course:cprog-1700000000" }

  before do
    # Autograder saves rewrite the assessment YAML; these courses have no directory.
    allow_any_instance_of(Assessment).to receive(:dump_yaml)
    @course = record(Course, name: "imported-#{SecureRandom.hex(4)}", display_name: "Imported")
    @assessment = record(Assessment, course_id: @course.id, name: "lab", display_name: "Lab")
    @autograder = record(Autograder, assessment_id: @assessment.id, autograde_image: old_uri,
                                     autograde_timeout: 180)
    @image = record(ContainerImage, course_id: @course.id, name: "CProg", status: 0,
                                    dockerfile_contents: "FROM ubuntu:22.04")
  end

  describe "ContainerImage#mark_built!" do
    it "moves autograders left on the source course's image onto the rebuilt image" do
      new_uri = "#{registry}/#{@course.name}:cprog-1800000000"
      @image.mark_built!(new_uri)
      expect(@autograder.reload.autograde_image).to eq(new_uri)
      expect(@image.reload.image_uri).to eq(new_uri)
    end

    it "leaves autograders that use another image name alone" do
      @autograder.update!(autograde_image: "#{registry}/source-course:other-1700000000")
      @image.mark_built!("#{registry}/#{@course.name}:cprog-1800000000")
      expect(@autograder.reload.autograde_image).to end_with("other-1700000000")
    end

    it "leaves autograders already on one of this course's images alone" do
      current = "#{registry}/#{@course.name}:cprog-1750000000"
      record(ContainerImage, course_id: @course.id, name: "CProg", status: 2, image_uri: current)
      @autograder.update!(autograde_image: current)
      @image.mark_built!("#{registry}/#{@course.name}:cprog-1800000000")
      expect(@autograder.reload.autograde_image).to eq(current)
    end

    it "does not touch other courses' autograders" do
      other = record(Course, name: "other-#{SecureRandom.hex(4)}", display_name: "Other")
      other_asmt = record(Assessment, course_id: other.id, name: "lab2", display_name: "Lab")
      other_ag = record(Autograder, assessment_id: other_asmt.id, autograde_image: old_uri,
                                    autograde_timeout: 180)
      @image.mark_built!("#{registry}/#{@course.name}:cprog-1800000000")
      expect(other_ag.reload.autograde_image).to eq(old_uri)
    end
  end

  describe CourseArchive::ImageRebuild do
    before { allow(Rails.configuration.x).to receive(:ec2_docker).and_return(true) }

    it "asks Tango to rebuild each imported draft image under the new course" do
      expect(TangoClient).to receive(:build_image)
        .with("CProg", @image.id, "FROM ubuntu:22.04", @course.name, nil, nil)
        .and_return("status" => 1)
      described_class.call(@course)
      expect(@image.reload.status).to eq("building")
    end

    it "marks images without a Dockerfile as failed instead of building" do
      @image.update!(dockerfile_contents: nil)
      expect(TangoClient).not_to receive(:build_image)
      described_class.call(@course)
      expect(@image.reload.status).to eq("failed")
    end

    it "does not raise when Tango is unreachable" do
      allow(TangoClient).to receive(:build_image).and_raise(TangoClient::TangoException, "down")
      expect { described_class.call(@course) }.not_to raise_error
      expect(@image.reload.status).to eq("failed")
    end
  end
end
