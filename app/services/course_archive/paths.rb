module CourseArchive
  module Paths
    def self.export_source!(path)
      # Also catch directory links in a handin path's parents, since handins
      # are copied separately from the assessment tree.
      root = Rails.root.to_s
      path.ascend do |entry|
        break unless entry == path || entry.to_s.start_with?("#{root}/")
        next unless entry.symlink? && entry.directory?

        raise Error, "Cannot export #{entry}: will not follow symlinks of folders " \
                     "when exporting to prevent infinite loops."
      end
      raise Error, "Only regular files and directories can be exported: #{path}" unless
        path.file? || path.directory?
    end

    def self.relative!(value)
      unless value.is_a?(String) && value.present? &&
             !value.match?(/[[:cntrl:]\\]/) && !Pathname.new(value).absolute? &&
             !value.split("/").include?("..") && Pathname.new(value).cleanpath.to_s != "."
        raise Error, "Unsafe relative path: #{value.inspect}"
      end

      value
    end

    def self.filename!(value)
      relative!(value)
      raise Error, "Unsafe filename: #{value.inspect}" if value.include?("/")

      value
    end

    def self.identifier!(value)
      raise Error, "Invalid identifier: #{value.inspect}" unless
        value.is_a?(String) && value.match?(/\A[A-Za-z0-9_-]+\z/)

      value
    end
  end
end
