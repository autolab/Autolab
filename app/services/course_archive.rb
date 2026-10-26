require "fileutils"
require "json"
require "pathname"
require "tmpdir"
require "yaml"

module CourseArchive
  class Error < StandardError; end

  FORMAT = "autolab_course_export".freeze
  VERSION = 3
  # This is also the insertion order. Adding a table requires an explicit query
  # and selection rule, not association discovery.
  TABLES = [
    ScoreAdjustment, User, Course, ContainerImage, CourseUserDatum, Group,
    Assessment, Autograder, Scoreboard, Attachment, Problem, Submission,
    AssessmentUserDatum, Extension, Score, Annotation
  ].index_by(&:table_name).freeze

  def self.export(course:, tar_path:, user_ids: [], assessment_ids: [])
    rows = Selection.from_course(course, user_ids:, assessment_ids:)
    Records.validate!(rows)
    Dir.mktmpdir("course-export-", Rails.root.join("tmp")) do |directory|
      root = Pathname.new(directory)
      Records.write(root, rows)
      Content.export(root, course, rows)
      Tarball.pack(root, tar_path)
    end
  end

  def self.import(tar_path:, identifier:, display_name:, instructor_email:,
                  user_ids: [], assessment_ids: [])
    Dir.mktmpdir("course-import-", Rails.root.join("tmp")) do |directory|
      root = Pathname.new(directory)
      Tarball.unpack(tar_path, root)
      rows = Records.read(root)
      rows = Selection.from_rows(rows, user_ids:, assessment_ids:)
      Records.validate!(rows)
      Restore.new(root, rows).call(identifier:, display_name:, instructor_email:)
    end
  end
end

require_relative "course_archive/paths"
require_relative "course_archive/tarball"
require_relative "course_archive/selection"
require_relative "course_archive/records"
require_relative "course_archive/content"
require_relative "course_archive/import_files"
require_relative "course_archive/restore"
