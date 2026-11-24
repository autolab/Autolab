require "rails_helper"
require Rails.root.join("app/services/course_archive")

RSpec.describe "Course archive export" do
  # Query tests need rows, without live course/submission filesystem callbacks.
  # rubocop:disable Rails/SkipsModelValidations
  def record(model, **attributes)
    %w[created_at updated_at].each do |field|
      attributes[field.to_sym] ||= Time.current if model.column_names.include?(field)
    end
    model.insert_all!([attributes])
    model.find_by!(attributes)
  end
  # rubocop:enable Rails/SkipsModelValidations

  before do
    @root = Pathname.new(Dir.mktmpdir("archive-export-spec-"))
    @course = record(Course, name: "archive-unit-#{SecureRandom.hex(4)}", display_name: "Course")
    @other_course = record(Course, name: "other-course")
    @user = record(User, email: "selected@example.test", first_name: "Selected",
                         encrypted_password: "never-export", administrator: true)
    @excluded = record(User, email: "excluded@example.test")
    @member = record(CourseUserDatum, course_id: @course.id, user_id: @user.id)
    @other_member = record(CourseUserDatum, course_id: @course.id, user_id: @excluded.id)
    @assessment = record(Assessment, course_id: @course.id, name: "lab", display_name: "Lab",
                                     handin_directory: "handin", handin_filename: "answer.txt")
    @private = record(Assessment, course_id: @course.id, name: "private-lab")
    @problem = record(Problem, assessment_id: @assessment.id, name: "correctness")
    @submission = record(Submission, assessment_id: @assessment.id,
                                     course_user_datum_id: @member.id,
                                     submitted_by_id: @other_member.id, version: 1,
                                     filename: "answer.txt")
    @excluded_submission = record(Submission, assessment_id: @assessment.id,
                                              course_user_datum_id: @other_member.id, version: 1)
    record(Submission, assessment_id: @private.id, course_user_datum_id: @member.id, version: 1)
    record(Score, submission_id: @submission.id, problem_id: @problem.id,
                  grader_id: @other_member.id, score: 9)
  end

  after do
    FileUtils.rm_rf(@root)
    FileUtils.rm_rf(@course.directory_path)
  end

  def rows
    CourseArchive::Selection.from_course(@course, user_ids: [@user.id],
                                                  assessment_ids: [@assessment.id])
  end

  it "exports exactly the selected course, roster, assessments, and submission intersection" do
    selected = rows

    expect(selected.keys).to contain_exactly(*CourseArchive::TABLES.keys)
    expect(selected.fetch("courses").pluck("_id")).to eq([@course.id])
    expect(selected.fetch("users").pluck("_id")).to eq([@user.id])
    expect(selected.fetch("course_user_data").pluck("_id")).to eq([@member.id])
    expect(selected.fetch("assessments").pluck("_id")).to eq([@assessment.id])
    expect(selected.fetch("submissions").pluck("_id")).to eq([@submission.id])
    expect(selected.fetch("scores").first.fetch("grader_id")).to eq(0)
    expect(selected.fetch("submissions").first.fetch("submitted_by_id")).to be_nil
  end

  it "allows course-only export and rejects IDs outside the source course" do
    empty = CourseArchive::Selection.from_course(@course, user_ids: [], assessment_ids: [])
    expect(empty.fetch("courses").size).to eq(1)
    expect(empty.fetch("users")).to be_empty
    expect(empty.fetch("assessments")).to be_empty
    outside = record(Assessment, course_id: @other_course.id, name: "outside")

    expect {
      CourseArchive::Selection.from_course(@course, user_ids: [], assessment_ids: [outside.id])
    }.to raise_error(CourseArchive::Error, /unavailable IDs/)
  end

  it "never adds an unselected owner to satisfy a stale latest-submission reference" do
    record(AssessmentUserDatum, assessment_id: @assessment.id, course_user_datum_id: @member.id,
                                latest_submission_id: @excluded_submission.id)
    selected = rows

    expect(selected.fetch("users").pluck("_id")).to eq([@user.id])
    expect(selected.fetch("submissions").pluck("_id")).to eq([@submission.id])
    expect { CourseArchive::Records.validate!(selected) }
      .to raise_error(CourseArchive::Error, /unavailable submissions/)
  end

  it "includes only groups and adjustments used by the selected records" do
    included = record(ScoreAdjustment, kind: 0, value: 1, type: "Tweak")
    record(ScoreAdjustment, kind: 0, value: 2, type: "Tweak")
    group = record(Group, name: "Selected team")
    record(Group, name: "Unselected team")
    # rubocop:disable Rails/SkipsModelValidations
    @member.update_column(:tweak_id, included.id)
    # rubocop:enable Rails/SkipsModelValidations
    record(AssessmentUserDatum, assessment_id: @assessment.id,
                                course_user_datum_id: @member.id, group_id: group.id)

    expect(rows.fetch("score_adjustments").pluck("_id")).to eq([included.id])
    expect(rows.fetch("groups").pluck("_id")).to eq([group.id])
  end

  it "writes ordinary YAML arrays and preview IDs without exporting account credentials" do
    CourseArchive::Records.write(@root, rows)
    submissions = YAML.safe_load(@root.join("submissions.yml").read)
    users = YAML.safe_load(@root.join("users.yml").read)
    preview = JSON.parse(@root.join("preview.json").read)
    manifest = YAML.safe_load(@root.join("manifest.yml").read)

    expect(submissions.first.fetch("_id")).to eq(@submission.id)
    expect(submissions.first.fetch("assessment_id")).to eq(@assessment.id)
    expect(users.first.keys).not_to include("encrypted_password", "administrator")
    expect(preview.fetch("users").first.fetch("id")).to eq(@user.id.to_s)
    expect(preview.fetch("assessments").first.fetch("id")).to eq(@assessment.id.to_s)
    expect(manifest).to include("format" => CourseArchive::FORMAT, "version" => 3)
    expect(YAML.safe_load(@root.join("annotations.yml").read)).to eq([])
  end

  it "separates shared material, assessment material, and selected users' handins" do
    handins = @assessment.handin_directory_path
    FileUtils.mkdir_p([handins.join(@user.email), handins.join(@excluded.email),
                       @private.folder_path])
    @course.directory_path.join("#{@excluded.email}-notes.txt").write("shared")
    @assessment.folder_path.join("handout.txt").write("handout")
    handins.join(@user.email, "answer.txt").write("submission")
    handins.join(@user.email, "extra.txt").write("auxiliary")
    handins.join(@excluded.email, "private.txt").write("excluded")
    @private.folder_path.join("private.txt").write("excluded assessment")
    CourseArchive::Content.export(@root, @course, rows)
    selected = @root.join("files/handins", @assessment.id.to_s, @user.id.to_s)

    expect(selected.join("answer.txt").read).to eq("submission")
    expect(selected.join("extra.txt").read).to eq("auxiliary")
    expect(@root.join("files/course", "#{@excluded.email}-notes.txt").read).to eq("shared")
    expect(@root.join("files/assessments", @assessment.id.to_s,
                      "handout.txt").read).to eq("handout")
    expect(@root.join("files/assessments", @assessment.id.to_s, "handin")).not_to exist
    expect(@root.join("files/assessments", @private.id.to_s)).not_to exist
    expect(@root.join("files/handins", @assessment.id.to_s, @excluded.id.to_s)).not_to exist
  end

  it "exports whole-handin annotations as null and preserves relative archive filenames" do
    [@submission.handin_file_path, "src/main.c"].each do |filename|
      record(Annotation, submission_id: @submission.id, problem_id: @problem.id,
                         filename:, comment: "Review this", value: 0)
    end
    tar_path = @root.join("annotated.tar")
    CourseArchive.export(course: @course, tar_path:, user_ids: [@user.id],
                         assessment_ids: [@assessment.id])
    CourseArchive::Tarball.unpack(tar_path, @root.join("unpacked"))
    exported = CourseArchive::Records.read(@root.join("unpacked"))

    expect(exported.fetch("annotations").pluck("filename")).to eq([nil, "src/main.c"])
    expect(@submission.annotations.order(:id).pluck(:filename))
      .to eq([@submission.handin_file_path, "src/main.c"])
  end

  it "rejects absolute annotation paths even inside the course unless they identify its handin" do
    record(Annotation, submission_id: @submission.id, problem_id: @problem.id,
                       filename: @course.directory_path.join("other.txt").to_s,
                       comment: "Wrong file", value: 0)

    expect { rows }.to raise_error(CourseArchive::Error, /does not reference its submission/)
  end

  it "skips missing submission files while keeping metadata and other course files" do
    handins = @assessment.handin_directory_path.join(@user.email)
    FileUtils.mkdir_p(handins)
    handins.join("extra.txt").write("available material")

    CourseArchive::Content.export(@root, @course, rows)
    CourseArchive::Records.write(@root, rows)
    exported = @root.join("files/handins", @assessment.id.to_s, @user.id.to_s)

    expect(exported.join("answer.txt")).not_to exist
    expect(exported.join("extra.txt").read).to eq("available material")
    expect(YAML.safe_load(@root.join("submissions.yml").read).pluck("_id")).to eq([@submission.id])
  end

  it "skips an attachment whose Active Storage bytes are missing" do
    attachment = record(Attachment, course_id: @course.id, filename: "missing.txt", name: "Missing",
                                    category_name: "General", release_at: Time.current)
    attachment.attachment_file.attach(io: StringIO.new("lost bytes"), filename: "missing.txt")
    blob = attachment.attachment_file.blob
    expect(blob).to be_persisted
    blob.service.delete(blob.key)

    CourseArchive::Content.export(@root, @course, rows)

    expect(@root.join("files/attachments", attachment.id.to_s, "missing.txt")).not_to exist
  end

  it "packs file bytes and empty directories into a regular tar" do
    source = @root.join("source")
    FileUtils.mkdir_p(source.join("empty"))
    source.join("notes.txt").write("course material")
    tar = @root.join("course.tar")
    CourseArchive::Tarball.pack(source, tar)
    entries = {}
    File.open(tar, "rb") do |input|
      Gem::Package::TarReader.new(input) do |archive|
        archive.each { |entry| entries[entry.full_name] = entry.file? ? entry.read : :directory }
      end
    end

    expect(entries).to include("notes.txt" => "course material", "empty" => :directory)
  end

  it "rejects directory links and enforces archive size limits on export" do
    source = @root.join("source")
    FileUtils.mkdir_p(source)
    source.join("link").make_symlink("/tmp")
    expect { CourseArchive::Content.copy_file(source.join("link"), @root.join("copy")) }
      .to raise_error(CourseArchive::Error, /symlinks of folders.*prevent infinite loops/)
    expect { CourseArchive::Tarball.pack(source, @root.join("unsafe.tar")) }
      .to raise_error(CourseArchive::Error, /symlinks of folders.*prevent infinite loops/)
    source.join("link").unlink
    source.join("large.txt").write("large")
    stub_const("CourseArchive::Tarball::MAX_ENTRY_BYTES", 1)

    expect { CourseArchive::Tarball.pack(source, @root.join("large.tar")) }
      .to raise_error(CourseArchive::Error, /too large/)
  end
end
