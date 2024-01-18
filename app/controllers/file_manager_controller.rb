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
    absolute_path = sanitize_path(check_path_exist(params[:path].nil? ? "" : params[:path]))
    instructor_paths = get_all_paths
    if File.directory?(absolute_path)
      populate_directory(absolute_path, "#{params[:path]}/")
      render 'file_manager/index'
    elsif File.file?(absolute_path)
      if File.size(absolute_path) > 1_000_000 || params[:download]
        if absolute_path.in?(instructor_paths)
          send_file absolute_path
        end
      elsif absolute_path.in?(instructor_paths)
        @file = File.read(absolute_path)
        render :file, formats: :html
      end
    end
  end

  def upload
    upload_file(params[:path].nil? ? "" : params[:path])
    path
  end

  def delete
    absolute_path = check_path_exist(params[:path])
    if File.directory?(absolute_path)
      FileUtils.rm_rf(absolute_path)
    else
      FileUtils.rm(absolute_path)
    end
    new_absolute_path = File.expand_path("..", absolute_path)
    path_split = new_absolute_path.split("/")
    courses_index = path_split.index("courses")
    result = path_split[(courses_index + 1)..(path_split.length - 1)].join("/")
    populate_directory(new_absolute_path, "")
    new_path = "#{file_manager_index_path}/#{result}"
    redirect_to new_path
  end

  def rename
    absolute_path = check_path_exist(params[:relative_path])
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
    flash[:success] = "File successfully renamed"
  rescue ArgumentError => e
    flash[:error] = e.message
  end

private

  def my_escape(string)
    string.gsub(/([^ a-zA-Z0-9_.-]+)/) do
      "%#{$1.unpack('H2' * $1.bytesize).join('%').upcase}"
    end
  end

  def populate_directory(current_directory, current_url)
    directory = Dir.entries(sanitize_path(current_directory))
    instructor_paths = get_all_paths
    @directory = directory.map do |file|
      abs_path_str = "#{current_directory}/#{file}"
      stat = File.stat(abs_path_str)
      is_file = stat.file?
      if [".", ".."].include?(file)
        inst = true
      else
        abs_path = Pathname.new(abs_path_str)
        inst = abs_path.in?(instructor_paths)
      end
      {
        size: (if is_file
                 begin
                   number_to_human_size stat.size
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

  def upload_file(path)
    absolute_path = check_path_exist(path)
    raise ActionController::ForbiddenError unless File.directory?(absolute_path)

    input_file = params[:file]
    return unless input_file

    all_filenames = Dir.entries(absolute_path)
    @duplicated_file = all_filenames.include?(input_file.original_filename)

    File.open(Rails.root.join(absolute_path, input_file.original_filename), 'wb') do |file|
      file.write(input_file.read)
    end
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

  def get_all_paths
    current_user_id = current_user.id
    cuds = CourseUserDatum.where(user_id: current_user_id, instructor: true)
    courses = cuds.map do |cud|
      Course.find_by(id: cud.course_id)
    end
    paths = courses.map do |course|
      Pathname.new("#{BASE_DIRECTORY}/#{course.name}")
    end
    children = paths.map do |path|
      get_all_children(path)
    end
    (children + paths).flatten.compact.uniq
  end

  def get_all_children(path)
    return [] unless path.exist?
    return [path] unless path.directory?

    children = path.children
    all_children = [children]
    children.map do |child|
      all_children += get_all_children(child)
    end
    all_children.flatten
  end

  def sanitize_path(path)
    allowed_pattern = %r{\A[a-zA-Z0-9_\-/]+(\.[a-zA-Z]+)?\z}
    unless path.to_s.match?(allowed_pattern)
      raise ActionController::ForbiddenError(path, 'is not in a valid format')
    end

    path
  end
end