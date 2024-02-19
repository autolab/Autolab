# Code for file manager adapted from: adrientoub/file-explorer
require 'archive'
require 'pathname'

class FileManagerController < ApplicationController
  BASE_DIRECTORY = Rails.root.join('courses')
  before_action :set_base_url
  skip_before_action :set_course
  skip_before_action :authorize_user_for_course
  skip_before_action :update_persistent_announcements

  def index
    check_path_exist('')
    populate_directory(BASE_DIRECTORY, '')
  end

  def upload_index
    upload_file('')
    populate_directory(BASE_DIRECTORY, '')
    render 'file_manager/index'
  end

  def path
    absolute_path = check_path_exist(params[:path].nil? ? "" : params[:path])
    if File.directory?(absolute_path) && check_instructor(absolute_path)
      populate_directory(absolute_path, "#{params[:path]}/")
      render 'file_manager/index'
    elsif File.file?(absolute_path) && check_instructor(absolute_path)
      if File.size(absolute_path) > 1_000_000 || params[:download]
        send_file absolute_path
      else
        @file = File.read(absolute_path)
        render :file, formats: :html
      end
    end
  end

  def upload
    upload_file(params[:path].nil? ? "" : params[:path])
  end

  def delete
    absolute_path = check_path_exist(params[:path])
    if check_instructor(absolute_path)
      if File.directory?(absolute_path)
        FileUtils.rm_rf(absolute_path)
      else
        FileUtils.rm(absolute_path)
      end
    end
    flash[:success] = "Successfully deleted"
  end

  def rename
    absolute_path = check_path_exist(params[:relative_path])
    if check_instructor(absolute_path)
      dir_name = File.dirname(params[:relative_path])

      if params[:new_name].empty?
        raise ArgumentError, "New name not provided,
        new name cannot be blank"
      end

      unless params[:new_name].match(/^[a-zA-Z0-9_-]+(\.[a-zA-Z0-9_-]+)?$/)
        raise ArgumentError, "Invalid characters. Only letters,
        numbers, underscores, and hyphens are allowed."
      end

      new_path = safe_expand_path("#{dir_name}/#{params[:new_name]}")
      parent = new_path.split[0..-2].join('/')

      original_has_extension = !File.extname(absolute_path).empty?

      if original_has_extension && File.extname(params[:new_name]).empty?
        raise ArgumentError,
              "You cannot name a file a folder"
      end
      if !original_has_extension && !File.extname(params[:new_name]).empty?
        raise ArgumentError,
              "You cannot name a folder a file"
      end

      raise ArgumentError, "A file with that name already exists" if File.exist?(new_path)

      FileUtils.mkdir_p(parent)
      FileUtils.mv(absolute_path, new_path)
      flash[:success] = "Successfully renamed file to #{params[:new_name]}"
    end
  rescue ArgumentError => e
    flash[:error] = e.message
  end

  def download_tar
    path = params[:path]&.split("/")&.drop(2)&.join("/")
    path = CGI.unescape(path)
    absolute_path = check_path_exist(path).to_s
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
    flash[:success] = "Download successful"
  end

private

  def upload_file(path)
    absolute_path = check_path_exist(path)
    if absolute_path.equal?(BASE_DIRECTORY)
      flash[:error] = "You cannot upload files in the root course directory " \
         "#{view_context.link_to 'here', new_course_url, method: 'get'}" \
         " if you want to create a new course."
      flash[:html_safe] = true
    else
      raise ActionController::ForbiddenError unless File.directory?(absolute_path)

      if check_instructor(absolute_path)
        if params[:name] != ""
          # Creating a folder
          dir = "#{absolute_path}/#{params[:name]}"
          FileUtils.mkdir_p(dir) unless File.directory?(dir)
          flash[:success] = "Successfully created folder"
        else
          # Uploading a file
          input_file = params[:file]
          return unless input_file

          all_filenames = Dir.entries(absolute_path)
          if all_filenames.include?(input_file.original_filename)
            flash[:error] = "File with name #{input_file.original_filename} already exists"
          else
            File.open(Rails.root.join(absolute_path, input_file.original_filename), 'wb') do |file|
              file.write(input_file.read)
            end
            flash[:success] = "Successfully uploaded file(s)"
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
    @directory = directory.map do |file|
      abs_path_str = "#{current_directory}/#{file}"
      stat = File.stat(abs_path_str)
      is_file = stat.file?
      if [".", ".."].include?(file)
        inst = true
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
        relative: my_escape("/file_manager/#{current_url}#{file}").gsub('%2F', '/'),
        entry: "#{file}#{is_file ? '' : '/'}",
        absolute: abs_path_str,
        instructor: inst,
      }
    end.sort_by { |entry| "#{entry[:type]}#{entry[:relative]}" }
  end

  def safe_expand_path(path)
    current_directory = Pathname.new(File.expand_path(BASE_DIRECTORY))
    tested_path = Pathname.new(File.expand_path(path, BASE_DIRECTORY))
    unless (current_directory == tested_path) || Archive.in_dir?(tested_path, current_directory)
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

  def set_base_url
    @base_url = '/file_manager'
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
      if path == course_path || Archive.in_dir?(path, course_path)
        return true
      end
    end
    false
  end
end
