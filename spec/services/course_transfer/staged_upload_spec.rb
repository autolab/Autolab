# frozen_string_literal: true

require "rails_helper"

RSpec.describe CourseTransfer::StagedUpload do
  let(:user) { FactoryBot.create(:user) }
  let(:upload) do
    path = Rails.root.join("spec/fixtures/courses/course-valid.tar")
    Rack::Test::UploadedFile.new(path, "application/x-tar")
  end

  after do
    described_class.clear_user!(user)
    FileUtils.rm_rf(described_class::STAGING_ROOT)
  end

  it "stages a file and finds it" do
    staged = described_class.stage!(user, upload)
    found = described_class.find!(user, staged.token)
    expect(found.path).to eq(staged.path)
    expect(found.original_filename).to be_present
    expect(found.byte_size).to be > 0
  end

  it "keeps at most one staged package per user" do
    first = described_class.stage!(user, upload)
    second = described_class.stage!(user, upload)
    expect(File).not_to exist(first.path)
    expect(File).to exist(second.path)
  end

  it "purges expired packages on stage" do
    staged = described_class.stage!(user, upload)
    old_time = 2.hours.ago.to_time
    File.utime(old_time, old_time, staged.path)
    meta = described_class::STAGING_ROOT.join(user.id.to_s, "#{staged.token}.json")
    File.utime(old_time, old_time, meta) if meta.file?

    other = FactoryBot.create(:user)
    described_class.stage!(other, upload)
    expect(File).not_to exist(staged.path)
    described_class.clear_user!(other)
  end

  it "cleans up staged files" do
    staged = described_class.stage!(user, upload)
    described_class.cleanup!(user, staged.token)
    expect(File).not_to exist(staged.path)
  end
end
