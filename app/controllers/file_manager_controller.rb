# Code for file manager adapted from: adrientoub/file-explorer
require 'archive'
require 'pathname'
require 'mimemagic'

class FileManagerController < ApplicationController
  BASE_DIRECTORY = Rails.root.join('courses')
  skip_before_action :set_course
  skip_before_action :authorize_user_for_course
  skip_before_action :update_persistent_announcements

  def index
    path = params[:path].nil? ? "" : params[:path]
    new_url = "#{path}/"
    parts = new_url.split('/')
    if parts.empty?
      @title = "File Manager"
    else
      @breadcrumbs << view_context.link_to("File Manager", file_manager_index_path)
    end
    parts.each_with_index do |part, index|
      path = new_url.split('/').slice(0, index + 1).join("/")
      if index == parts.length - 1
        @title = part
      else
        @breadcrumbs << view_context.link_to(part, "/file_manager/#{path}")
      end
    end
    absolute_path = check_path_exist(path)
    if (directory_path?(absolute_path) && check_instructor(absolute_path)) ||
       (path == "" && is_instructor_of_any_course)
      populate_directory(absolute_path, new_url)
      render 'file_manager/index'
    elsif file_path?(absolute_path) && check_instructor(absolute_path)
      if file_size_bytes(absolute_path).to_i > 1_000_000 || params[:download]
        stream_file_with_fallback(absolute_path,
                                  filename: File.basename(absolute_path),
                                  disposition: 'attachment')
      elsif !is_binary_file?(absolute_path)
        @path = path
        @file = read_binary_file(absolute_path)&.force_encoding("UTF-8")
        render :file, formats: :html
      else
        stream_file_with_fallback(absolute_path,
                                  filename: File.basename(absolute_path),
                                  disposition: 'attachment')
      end
    else
      flash[:error] = "You are not authorized to view this path"
      redirect_to root_path
    end
  end

  def upload
    upload_file(params[:path].nil? ? "" : params[:path])
  end

  def delete
    absolute_path = check_path_exist(params[:path])
    if check_instructor(absolute_path)
      parent = absolute_path.parent
      raise "Unable to delete courses in the root directory." if parent == BASE_DIRECTORY

      FileUtils.rm_r(absolute_path)
      if path_exists?(absolute_path)
        raise SystemCallError, "Delete operation did not remove #{absolute_path}"
      end

      respond_to do |format|
        format.html do
          flash[:success] = "Deleted successfully."
          redirect_to(file_manager_index_path(path: parent.relative_path_from(BASE_DIRECTORY).to_s))
        end
        format.json { render json: { success: true }, status: :ok }
        format.js { head :ok }
      end
    else
      flash[:error] = "You are not authorized to delete this"
      respond_to do |format|
        format.html { redirect_to root_path }
        format.json { render json: { success: false, error: flash[:error] }, status: :forbidden }
        format.js { head :forbidden }
      end
    end
  rescue Errno::EACCES, Errno::EPERM
    flash[:error] = "Unable to delete this path due to filesystem permissions."
    respond_to do |format|
      format.html { redirect_to root_path }
      format.json {
        render json: { success: false, error: flash[:error] }, status: :unprocessable_entity
      }
      format.js { head :unprocessable_entity }
    end
  rescue StandardError => e
    flash[:error] = "Unable to delete this path. (#{e.message})"
    respond_to do |format|
      format.html { redirect_to root_path }
      format.json {
        render json: { success: false, error: flash[:error] }, status: :unprocessable_entity
      }
      format.js { head :unprocessable_entity }
    end
  end

  def rename
    absolute_path = check_path_exist(params[:relative_path])
    if check_instructor(absolute_path)
      parent = absolute_path.parent
      if parent == BASE_DIRECTORY
        flash[:error] = "Unable to rename courses in the root directory."
      else
        dir_name = File.dirname(params[:relative_path].to_s)

        if params[:new_name].nil? || params[:new_name].empty?
          raise ArgumentError, "New name not provided"
        end

        unless params[:new_name].match(/\A[a-zA-Z0-9_\-.\s]+\Z/)
          raise ArgumentError, "Invalid characters. Only letters,
        numbers, underscores, and hyphens are allowed."
        end

        new_path = safe_expand_path("#{dir_name}/#{params[:new_name]}")
        parent = new_path.dirname

        raise ArgumentError, "A file with that name already exists" if path_exists?(new_path)

        create_directory_path(parent)

        # Under the delegated permission model, source/parent paths can be unreadable/unwritable
        # to the webapp process. Best-effort permission repair before moving.
        FilesystemEnforcer.fix_path(absolute_path.to_s)
        FilesystemEnforcer.fix_path(absolute_path.parent.to_s)
        FilesystemEnforcer.fix_path(parent.to_s)

        FileUtils.mv(absolute_path, new_path)
        FilesystemEnforcer.fix_path(new_path.to_s)
        flash[:success] = "Successfully renamed file to #{params[:new_name]}"
      end
    else
      flash[:error] = "You are not authorized to rename this path"
      redirect_to root_path
    end
  rescue ArgumentError => e
    flash[:error] = e.message
  rescue Errno::EACCES, Errno::EPERM
    flash[:error] = "Unable to rename this path due to filesystem permissions."
  rescue SystemCallError => e
    flash[:error] = "Unable to rename this path. (#{e.message})"
  end

  def download_tar
    path = params[:path]&.split("/")&.drop(2)&.join("/")
    path = CGI.unescape(path)
    absolute_path = check_path_exist(path)
    if check_instructor(absolute_path)
      if File.directory?(absolute_path)
        tar_stream = StringIO.new("")
        Gem::Package::TarWriter.new(tar_stream) do |tar|
          Dir[File.join(absolute_path.to_s, '**', '**')].each do |file|
            mode = File.stat(file).mode
            relative_path = file.sub(%r{^#{Regexp.escape(absolute_path.to_s)}/?}, '')
            if File.directory?(file)
              tar.mkdir relative_path, mode
            else
              tar.add_file relative_path, mode do |tar_file|
                File.open(file, "rb") { |f| tar_file.write f.read }
              end
            end
          end
        end
        tar_stream.rewind
        tar_stream.close
        send_data tar_stream.string.force_encoding("binary"),
                  filename: "file_manager.tar",
                  type: "application/x-tar",
                  disposition: "attachment"
      else
        stream_file_with_fallback(absolute_path,
                                  filename: File.basename(absolute_path),
                                  disposition: 'attachment')
      end
    else
      flash[:error] = "You are not authorized to download attachments at this path"
      redirect_to root_path
    end
  end

  def upload_file(path)
    absolute_path = check_path_exist(path)
    if Archive.in_dir?(BASE_DIRECTORY, absolute_path, strict: false)
      raise "You cannot upload files/create folders in the root directory click " \
        "#{view_context.link_to 'here', new_course_url, method: 'get'}" \
        " if you want to create a new course."
    else
      raise ActionController::ForbiddenError unless directory_path?(absolute_path)

      if check_instructor(absolute_path) && !params[:name].nil?
        all_filenames = directory_entries(absolute_path)
        if params[:name] != ""
          if all_filenames.include?(params[:name].to_s)
            raise "File with name #{input_file.original_filename} already exists."
          end

          # Creating a folder
          dir = "#{absolute_path}/#{params[:name]}"
          create_directory_path(dir)
          FilesystemEnforcer.fix_path(dir)

        else
          # Uploading a file
          input_file = params[:file]
          return unless input_file
          if all_filenames.include?(input_file.original_filename)
            raise "File with name #{input_file.original_filename} already exists."
          elsif input_file.size >= 1.gigabyte
            raise "File size is too large. Upload a file that is smaller than 1 GB."
          else
            dest = absolute_path.join(input_file.original_filename)
            write_binary_file(dest, input_file.read)
            FilesystemEnforcer.fix_path(dest.to_s)
          end
        end
      else
        flash[:error] = "You are not authorized to upload files at this path"
        redirect_to root_path
      end
    end
  end

private

  def populate_directory(current_directory, current_url)
    directory = directory_entries(current_directory)
    new_url = current_url == '/' ? '' : current_url
    @directory = directory.map do |file|
      abs_path_str = "#{current_directory}/#{file}"
      stat = begin
        File.stat(abs_path_str)
      rescue StandardError
        nil
      end
      is_file = stat ? stat.file? : file_path?(abs_path_str)
      if %w[. ..].include?(file)
        inst = true
        if current_directory == BASE_DIRECTORY
          inst = false
        end
      else
        abs_path = Pathname.new(abs_path_str)
        inst = check_instructor(abs_path)
      end
      {
        size: (if is_file
                 begin
                   stat ? stat.size : file_size_bytes(abs_path_str)
                 rescue StandardError
                   '-'
                 end
               else
                 '-'
               end),
        type: (is_file ? :file : :directory),
        date: begin
          stat ? stat.mtime.strftime('%d %b %Y %H:%M') : '-'
        rescue StandardError
          '-'
        end,
        relative: "/file_manager/#{new_url}#{file}",
        entry: "#{file}#{is_file ? '' : '/'}",
        absolute: abs_path_str,
        instructor: inst,
      }
    end.sort_by { |entry| "#{entry[:type]}#{entry[:relative]}" }
  end

  def safe_expand_path(path)
    current_directory = Pathname.new(BASE_DIRECTORY)
    tested_path = Pathname.new(File.join(BASE_DIRECTORY, path))
    unless Archive.in_dir?(tested_path, current_directory, strict: false)
      raise ArgumentError, 'Should not be parent of root'
    end

    tested_path
  end

  def check_path_exist(path)
    @absolute_path = safe_expand_path(path)
    @relative_path = path
    raise ActionController::RoutingError, 'Not Found' unless path_exists?(@absolute_path)

    @absolute_path
  end

  def path_exists?(path)
    return false if path.nil?

    return true if File.exist?(path)

    return false unless UnixGroupManager.delegate_enabled?

    entries = UnixGroupManager.list_dir_via_delegate(File.dirname(path.to_s))
    entries&.include?(File.basename(path.to_s)) || false
  rescue Errno::EACCES, Errno::EPERM
    return false unless UnixGroupManager.delegate_enabled?

    entries = UnixGroupManager.list_dir_via_delegate(File.dirname(path.to_s))
    entries&.include?(File.basename(path.to_s)) || false
  end

  def directory_path?(path)
    return true if File.directory?(path)
    return false unless UnixGroupManager.delegate_enabled?

    !UnixGroupManager.list_dir_via_delegate(path.to_s).nil?
  rescue Errno::EACCES, Errno::EPERM
    return false unless UnixGroupManager.delegate_enabled?

    !UnixGroupManager.list_dir_via_delegate(path.to_s).nil?
  end

  def file_path?(path)
    return false unless path_exists?(path)

    !directory_path?(path)
  end

  def directory_entries(path)
    Dir.entries(path)
  rescue Errno::EACCES, Errno::EPERM
    return [] unless UnixGroupManager.delegate_enabled?

    entries = UnixGroupManager.list_dir_via_delegate(path.to_s) || []
    [".", "..", *entries]
  end

  def file_size_bytes(path)
    File.size(path)
  rescue Errno::EACCES, Errno::EPERM
    content = read_binary_file(path)
    content ? content.bytesize : 0
  end

  def read_binary_file(path)
    File.binread(path)
  rescue Errno::EACCES, Errno::EPERM
    return nil unless UnixGroupManager.delegate_enabled?

    UnixGroupManager.read_file_via_delegate(path.to_s)
  end

  def create_directory_path(path)
    FileUtils.mkdir_p(path)
  rescue Errno::EACCES, Errno::EPERM
    created = UnixGroupManager.mkdir_p_via_delegate(path.to_s, mode: 0o2770)
    raise Errno::EACCES, "Permission denied creating directory #{path}" unless created
  end

  def write_binary_file(path, content)
    File.binwrite(path, content)
  rescue Errno::EACCES, Errno::EPERM
    ok = UnixGroupManager.write_file_via_delegate(path.to_s, content)
    raise Errno::EACCES, "Permission denied writing file #{path}" unless ok
  end

  def stream_file_with_fallback(path, filename:, disposition:)
    send_file(path.to_s, filename:, disposition:)
  rescue ActionController::MissingFile, Errno::EACCES, Errno::EPERM
    content = read_binary_file(path)
    raise ActionController::MissingFile, "Cannot read file #{path}" if content.nil?

    send_data(content,
              filename:,
              disposition:)
  end

  def is_instructor_of_any_course
    current_user_id = current_user.id
    cuds = CourseUserDatum.where(user_id: current_user_id, instructor: true)
    courses = Course.where(id: cuds.map(&:course_id))
    !courses.empty?
  end

  def check_instructor(path)
    current_user_id = current_user.id
    cuds = CourseUserDatum.where(user_id: current_user_id, instructor: true)
    courses = Course.where(id: cuds.map(&:course_id))
    courses.map do |course|
      course_path = Pathname.new("#{BASE_DIRECTORY}/#{course.name}")
      if Archive.in_dir?(path, course_path, strict: false)
        return true
      end
    end
    false
  end

  def is_binary_file?(path)
    mm = MimeMagic.by_path(path)
    mm.present? && !mm.text?
  end
end
