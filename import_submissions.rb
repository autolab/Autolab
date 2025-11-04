require 'zip'
require 'fileutils'
require 'tempfile'
require 'rack/test'
include Rack::Test::Methods

# Usage: rails runner import_submissions.rb path/to/zipfile.zip "Assessment Name"

zip_path = ARGV[0]
assessment_name = ARGV[1]

unless zip_path && assessment_name
  puts "Usage: rails runner import_submissions.rb path/to/zipfile.zip \"Assessment Name\""
  exit 1
end

# Replace this with your actual course ID
course_name = "18213-m25"  # <-- change this to your course name
course = Course.find_by(name: course_name)
unless course
  puts "Course not found for name #{course_name}"
  exit 1
end

assessment = course.assessments.find_by(name: assessment_name)
unless assessment
  puts "Assessment '#{assessment_name}' not found in course ID #{course_name}"
  exit 1
end

temp_dir = Dir.mktmpdir

begin
  Zip::File.open(zip_path) do |zip_file|
    zip_file.each do |entry|
      # Match filenames like <username>_<id>_<assessment>-handin.tar
      next unless entry.name =~ /\A(.+?)_\d+?_#{Regexp.escape(assessment_name)}-handin\.tar\z/

      username = Regexp.last_match(1)
      user = User.find_by(email: username)
      unless user
        puts "User not found: #{username}"
        next
      end

      cud = CourseUserDatum.find_by(user_id: user.id, course_id: course.id)
      unless cud
        puts "CourseUserDatum not found for #{username}"
        next
      end

      puts "Creating submission for #{username}"

      # Extract tar to temporary path
      temp_tar_path = File.join(temp_dir, entry.name)
      entry.extract(temp_tar_path) { true }

      submission = Submission.new(
        assessment_id: assessment.id,
        course_user_datum_id: cud.id,
        submitted_by_id: cud.id,
        notes: "Bulk uploaded from ZIP",
        special_type: nil
      )

      begin
        submission.save!
        file_param = { "file" => Rack::Test::UploadedFile.new(temp_tar_path, "application/x-tar") }
        submission.save_file(file_param)
        puts "Successfully created submission for #{username}"
      rescue => e
        puts "Failed to create submission for #{username}: #{e.message}"
      end
    end
  end
ensure
  FileUtils.remove_entry(temp_dir)
end
