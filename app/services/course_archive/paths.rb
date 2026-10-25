module CourseArchive
  module Paths
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
