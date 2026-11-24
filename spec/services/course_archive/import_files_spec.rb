require "rails_helper"
require Rails.root.join("app/services/course_archive")

RSpec.describe CourseArchive::ImportFiles do
  before do
    @root = Pathname.new(Dir.mktmpdir("import-permissions-"))
    @path = @root.join("destination")
    allow(UnixGroupManager).to receive(:delegate_enabled?).and_return(true)
    allow(UnixGroupManager).to receive(:delegate_action).with("chown", anything).and_return(true)
    allow(UnixGroupManager).to receive(:chmod_path) { |path, mode| File.chmod(mode, path); true }
  end

  after do
    FileUtils.chmod_R(0o700, @root)
    FileUtils.rm_rf(@root)
  end

  it "leaves writable destinations and existing course subdirectories alone" do
    FileUtils.mkdir_p(@path.join("existing-course"))
    @path.join("existing-course").chmod(0o500)
    expect(UnixGroupManager).not_to receive(:delegate_action)
    described_class.prepare_directory(@path)
    expect(@path.join("existing-course").stat.mode & 0o777).to eq(0o500)
  end

  it "creates a destination through the delegate when the parent denies mkdir" do
    @root.chmod(0o500)
    expect(UnixGroupManager).to receive(:mkdir_p_via_delegate).with(@path.to_s, mode: 0o755) do
      @root.chmod(0o700)
      Dir.mkdir(@path, 0o500)
      true
    end
    described_class.prepare_directory(@path)
    expect(@path).to be_writable
    expect(@path.stat.mode & 0o777).to eq(0o700)
  end

  it "fails when permission repair fails instead of continuing an incomplete import" do
    Dir.mkdir(@path, 0o500)
    allow(UnixGroupManager).to receive(:delegate_action).and_return(false)
    expect { described_class.prepare_directory(@path) }.to raise_error(Errno::EACCES)
  end

  it "delegates cleanup when final permissions prevent removing imported files" do
    Dir.mkdir(@path)
    @path.join("handin.txt").write("submission")
    @path.chmod(0o500)
    expect(UnixGroupManager).to receive(:delegate_action)
      .with("delete_path", path: @path.to_s, recursive: true) do
        @path.chmod(0o700)
        FileUtils.remove_entry(@path)
        true
      end
    described_class.remove(@path, recursive: true)
    expect(@path).not_to exist
  end
end
