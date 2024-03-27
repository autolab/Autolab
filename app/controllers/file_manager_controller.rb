# Code for file manager adapted from: adrientoub/file-explorer
require 'archive'
require 'pathname'

class FileManagerController < ApplicationController
  BASE_DIRECTORY = Rails.root.join('courses')
  skip_before_action :set_course
  skip_before_action :authorize_user_for_course
  skip_before_action :update_persistent_announcements

  def index
    path = params[:path].nil? ? "" : params[:path]
    absolute_path = check_path_exist(path)
    if (File.directory?(absolute_path) && check_instructor(absolute_path) ) || path == ""
      populate_directory(absolute_path, "#{path}/")
      render 'file_manager/index'
    elsif File.file?(absolute_path) && check_instructor(absolute_path)
      if File.size(absolute_path) > 1_000_000 || params[:download]
        send_file absolute_path
      else
        @file = File.read(absolute_path)
        @path = path
        render :file, formats: :html
      end
    end
  end

  def upload
    upload_file(params[:path].nil? ? "" : params[:path])
  end

  def delete
    absolute_path = check_path_exist(params[:path])
    return unless check_instructor(absolute_path)

    absolute_path = check_path_exist(params[:path])
    current_path = Pathname.new(absolute_path)
    parent = current_path.parent
    raise "Unable to delete courses in the root directory." if parent == BASE_DIRECTORY

    FileUtils.rm_rf(absolute_path)
  end

  def rename
    absolute_path = check_path_exist(params[:relative_path])
    if check_instructor(absolute_path)
      current_path = Pathname.new(absolute_path)
      parent = current_path.parent
      if parent == BASE_DIRECTORY
        flash[:error] = "Unable to rename courses in the root directory."
      else
        dir_name = File.dirname(params[:relative_path])

        if params[:new_name].empty? || params[:new_name].nil?
          raise ArgumentError, "New name not provided"
        end

        unless params[:new_name].match(/\A[a-zA-Z0-9_-]+(\.[a-zA-Z0-9_-]+)?\Z/)
          raise ArgumentError, "Invalid characters. Only letters,
        numbers, underscores, and hyphens are allowed."
        end

        new_path = safe_expand_path("#{dir_name}/#{params[:new_name]}")
        parent = new_path.split[0..-2].join('/')

        raise ArgumentError, "A file with that name already exists" if File.exist?(new_path)

        FileUtils.mkdir_p(parent)
        FileUtils.mv(absolute_path, new_path)
        flash[:success] = "Successfully renamed file to #{params[:new_name]}"
      end
    end
  rescue ArgumentError => e
    flash[:error] = e.message
  end

  def download_tar
    path = params[:path]&.split("/")&.drop(2)&.join("/")
    path = CGI.unescape(path)
    absolute_path = check_path_exist(path).to_s
    return unless check_instructor(absolute_path)

    if File.directory?(absolute_path)
      tar_stream = StringIO.new("")
      Gem::Package::TarWriter.new(tar_stream) do |tar|
        Dir[File.join(absolute_path, '**', '**')].each do |file|
          mode = File.stat(file).mode
          relative_path = file.sub(%r{^#{Regexp.escape(absolute_path)}/?}, '')
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
      send_file(absolute_path,
                filename: File.basename(absolute_path),
                disposition: 'attachment')
    end
  end

  def upload_file(path)
    absolute_path = check_path_exist(path)
    if Archive.in_dir?(BASE_DIRECTORY, absolute_path, strict: false)
      raise "You cannot upload files/create folders in the root directory click " \
        "#{view_context.link_to 'here', new_course_url, method: 'get'}" \
        " if you want to create a new course."
    else
      raise ActionController::ForbiddenError unless File.directory?(absolute_path)

      if check_instructor(absolute_path) && !params[:name].nil?
        all_filenames = Dir.entries(absolute_path)
        if params[:name] != ""
          if all_filenames.include?(params[:name].to_s)
            raise "File with name #{input_file.original_filename} already exists."
          end

          # Creating a folder
          dir = "#{absolute_path}/#{params[:name]}"
          FileUtils.mkdir_p(dir)

        else
          # Uploading a file
          input_file = params[:file]
          return unless input_file
          if all_filenames.include?(input_file.original_filename)
            raise "File with name #{input_file.original_filename} already exists."
          elsif input_file.size >= 1.gigabyte
            raise "File size is too large. Upload a file that is smaller than 1 GB."
          else
            File.open(Rails.root.join(absolute_path, input_file.original_filename), 'wb') do |file|
              file.write(input_file.read)
            end
          end
        end
      end
    end
  end

  def my_escape(string)
    string.gsub(/([^ a-zA-Z0-9_.-]+)/) do
      "%#{$1.unpack('H2' * $1.bytesize).join('%').upcase}"
    end
  end

  def populate_directory(current_directory, current_url)
    directory = Dir.entries(current_directory)
    new_url = current_url == '/' ? '' : current_url
    @directory = directory.map do |file|
      abs_path_str = "#{current_directory}/#{file}"
      stat = File.stat(abs_path_str)
      is_file = stat.file?
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
                   stat.size
                 rescue StandardError
                   '-'
                 end
               else
                 '-'
               end),
        type: (is_file ? :file : :directory),
        date: begin
          stat.mtime.strftime('%d %b %Y %H:%M')
        rescue StandardError
          '-'
        end,
        relative: CGI.unescape(my_escape("/file_manager/#{new_url}#{file}")),
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
    raise ActionController::RoutingError, 'Not Found' unless File.exist?(@absolute_path)

    @absolute_path
  end

  def check_instructor(path)
    current_user_id = current_user.id
    path = Pathname.new(path)
    cuds = CourseUserDatum.where(user_id: current_user_id, instructor: true)
    courses = cuds.map do |cud|
      Course.find_by(id: cud.course_id)
    end
    courses.map do |course|
      course_path = Pathname.new("#{BASE_DIRECTORY}/#{course.name}")
      if Archive.in_dir?(path, course_path, strict: false)
        return true
      end
    end
    false
  end
end
