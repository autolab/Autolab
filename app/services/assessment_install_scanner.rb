# frozen_string_literal: true

# AssessmentInstallScanner encapsulates the filesystem traversal logic that
# identifies assessment directories eligible for installation. It returns the
# list of unused assessment folders as well as any human-readable errors that
# should be surfaced to instructors.
class AssessmentInstallScanner
  Error = Struct.new(:message, :html_safe, keyword_init: true)
  Result = Struct.new(:unused_config_files, :errors, keyword_init: true) do
    def to_h
      {
        unused_config_files: unused_config_files || [],
        errors: (errors || []).map { |err| { message: err.message, html_safe: err.html_safe } }
      }
    end
  end

  def self.scan(course:)
    new(course).scan
  end

  def initialize(course)
    @course = course
    @dir_path = course.directory_path
  end

  def scan
    unused = []
    errors = []

    Dir.foreach(@dir_path) do |filename|
      next unless directory_entry?(filename)

      absolute_path = File.join(@dir_path, filename)
      next unless File.directory?(absolute_path)

      unless valid_assessment_name?(filename)
        errors << Error.new(message: invalid_name_message(filename), html_safe: true)
        next
      end

      unless yaml_exists?(absolute_path, filename)
        errors << Error.new(message: missing_yaml_message(filename), html_safe: true)
        next
      end

      unused << filename unless assessment_exists?(filename)
    end

    Result.new(unused_config_files: unused.sort, errors: errors)
  rescue Errno::ENOENT => e
    errors = [Error.new(message: "Course directory #{@dir_path} is missing: #{e.message}", html_safe: false)]
    Result.new(unused_config_files: [], errors: errors)
  end

  private

  def directory_entry?(filename)
    filename != "." && filename != ".."
  end

  def valid_assessment_name?(name)
    name =~ Assessment::VALID_NAME_REGEX
  end

  def yaml_exists?(absolute_path, filename)
    File.exist?(File.join(absolute_path, "#{filename}.yml"))
  end

  def assessment_exists?(name)
    @course.assessments.exists?(name: name)
  end

  def invalid_name_message(filename)
    "An error occurred while trying to display an existing assessment from file directory #{filename}: " \
      "Invalid assessment name. Find more information on valid assessment names " \
      '<a href="https://docs.autolabproject.com/lab/#assessment-naming-rules">here</a>'
  end

  def missing_yaml_message(filename)
    "An error occurred while trying to display an existing assessment from file directory #{filename}: " \
      "#{filename}.yml does not exist"
  end
end
