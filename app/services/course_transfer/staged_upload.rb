require "fileutils"
require "json"
require "securerandom"
require_relative "errors"

module CourseTransfer
  class StagedUpload
    STAGING_ROOT = Rails.root.join("tmp/course_imports")
    TTL = 30.minutes
    MAX_UPLOAD_BYTES = Integer(
      ENV.fetch("AUTOLAB_COURSE_TRANSFER_MAX_UPLOAD_BYTES", "536870912")
    )
    TOKEN_PATTERN = /\A[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\z/i

    class NotFound < Error; end
    class Expired < Error; end
    class TooLarge < Error; end

    Staged = Struct.new(
      :token, :path, :original_filename, :byte_size, :uploaded_at,
      keyword_init: true
    )

    def self.purge_expired!(now: Time.current)
      return unless STAGING_ROOT.directory?

      cutoff = now - TTL
      Dir.glob(STAGING_ROOT.join("**", "*")).each do |path|
        next unless File.file?(path)
        next unless File.mtime(path) < cutoff

        FileUtils.rm_f(path)
      end
    end

    def self.clear_user!(user)
      dir = user_dir(user)
      FileUtils.rm_rf(dir) if dir.directory?
    end

    def self.stage!(user, uploaded_file)
      raise ArgumentError, "uploaded file is required" if uploaded_file.blank?

      purge_expired!
      clear_user!(user)

      token = SecureRandom.uuid
      dir = user_dir(user)
      FileUtils.mkdir_p(dir)

      tar_path = dir.join("#{token}.tar")
      begin
        File.open(tar_path, "wb") do |out|
          source = uploaded_file.tempfile
          source.rewind if source.respond_to?(:rewind)
          copied = IO.copy_stream(source, out, MAX_UPLOAD_BYTES + 1)
          raise TooLarge, "uploaded package exceeds the size limit" if copied > MAX_UPLOAD_BYTES
        end

        uploaded_at = Time.current
        meta = {
          "original_filename" => uploaded_file.original_filename.to_s,
          "byte_size" => File.size(tar_path),
          "uploaded_at" => uploaded_at.utc.iso8601
        }
        dir.join("#{token}.json").write(JSON.generate(meta))
      rescue StandardError
        FileUtils.rm_f(tar_path)
        raise
      end

      Staged.new(
        token:,
        path: tar_path,
        original_filename: meta["original_filename"],
        byte_size: meta["byte_size"],
        uploaded_at:
      )
    end

    def self.find!(user, token)
      raise NotFound, "invalid staging token" unless token.to_s.match?(TOKEN_PATTERN)

      tar_path = user_dir(user).join("#{token}.tar")
      meta_path = user_dir(user).join("#{token}.json")
      raise NotFound, "staged upload not found" unless tar_path.file?

      if File.mtime(tar_path) < TTL.ago
        cleanup!(user, token)
        raise Expired, "staged upload expired"
      end

      meta = if meta_path.file?
               JSON.parse(meta_path.read)
             else
               {
                 "original_filename" => File.basename(tar_path.to_s),
                 "byte_size" => File.size(tar_path),
                 "uploaded_at" => File.mtime(tar_path).utc.iso8601
               }
             end

      Staged.new(
        token: token.to_s,
        path: tar_path,
        original_filename: meta["original_filename"],
        byte_size: meta["byte_size"].to_i,
        uploaded_at: Time.zone.parse(meta["uploaded_at"].to_s) || File.mtime(tar_path)
      )
    end

    def self.cleanup!(user, token)
      return if token.blank? || !token.to_s.match?(TOKEN_PATTERN)

      dir = user_dir(user)
      FileUtils.rm_f(dir.join("#{token}.tar"))
      FileUtils.rm_f(dir.join("#{token}.json"))
      FileUtils.rmdir(dir) if dir.directory? && Dir.empty?(dir.to_s)
    rescue Errno::ENOTEMPTY, Errno::ENOENT
      # ignore concurrent cleanup
    end

    def self.user_dir(user)
      STAGING_ROOT.join(user.id.to_s)
    end
    private_class_method :user_dir
  end
end
