# Code for file manager adapted from: adrientoub/file-explorer
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
    absolute_path = check_path_exist(params[:path])
    if File.directory?(absolute_path)
      populate_directory(absolute_path, "#{params[:path]}/")
      render 'file_manager/index'
    elsif File.file?(absolute_path)
      if File.size(absolute_path) > 1_000_000 || params[:download]
        send_file sanitize_path(absolute_path)
      else
        @file = File.read(sanitize_path(absolute_path))
        render :file, formats: :html
      end
    end
  end

  def upload
    upload_file(params[:path])
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

    raise ArgumentError, "New name not provided,
      new name cannot be blank" if params[:new_name].empty?

    unless params[:new_name].match(/^[a-zA-Z0-9_\-]+(\.[a-zA-Z0-9_\-]+)?$/)
      raise ArgumentError, "Invalid characters. Only letters,
        numbers, underscores, and hyphens are allowed."
    end

    new_path = safe_expand_path(dir_name + "/" + params[:new_name])
    parent = new_path.split('/')[0..-2].join('/')

    original_has_extension = !File.extname(absolute_path).empty?

    if original_has_extension && File.extname(params[:new_name]).empty?
      raise ArgumentError, "You cannot name a file a folder"
    elsif !original_has_extension && !File.extname(params[:new_name]).empty?
      raise ArgumentError, "You cannot name a folder a file"
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
      '%' + $1.unpack('H2' * $1.bytesize).join('%').upcase
    end
  end

  def populate_directory(current_directory, current_url)
    directory = Dir.entries(current_directory)
    @directory = directory.map do |file|
      real_path_absolute = "#{current_directory}/#{file}"
      stat = File.stat(real_path_absolute)
      is_file = stat.file?
      rel_path = "#{current_url}/#{file}"
      base_dir = rel_path.split('/').reject(&:empty?).first
      if base_dir  == "." or base_dir  == ".."
        instructor = true
      else
        course = Course.find_by(name: base_dir)
        if course
          cud = CourseUserDatum.find_by(course_id: course.id, user_id: current_user.id)
          instructor = cud.instructor?
        else
          instructor = false
        end
      end
      {
        size: (is_file ? (number_to_human_size stat.size rescue '-'): '-'),
        type: (is_file ? :file : :directory),
        date: (stat.mtime.strftime('%d %b %Y %H:%M') rescue '-'),
        relative: my_escape("/file_manager/#{current_url}#{file}").gsub('%2F', '/'),
        entry: "#{file}#{is_file ? '': '/'}",
        absolute: real_path_absolute,
        instructor: instructor,
      }
    end.sort_by { |entry| "#{entry[:type]}#{entry[:relative]}" }
  end

  def safe_expand_path(path)
    current_directory = File.expand_path(BASE_DIRECTORY)
    tested_path = File.expand_path(path, BASE_DIRECTORY)
    unless Archive.in_dir?(tested_path, current_directory)
      raise ArgumentError, 'Should not be parent of root'
    end
    tested_path
  end

  def upload_file(path)
    absolute_path = check_path_exist(path)
    raise ActionController::ForbiddenError unless File.directory?(absolute_path)
    input_file = params[:file]
    if input_file
      File.open(Rails.root.join(absolute_path, input_file.original_filename), 'wb') do |file|
        file.write(input_file.read)
      end
    end
  end

  def check_path_exist(path)
    @absolute_path = safe_expand_path(path)
    @relative_path = path
    raise ActionController::RoutingError, 'Not Found' unless File.exists?(@absolute_path)
    @absolute_path
  end

  def set_base_url
    @base_url = '/file_manager'
  end

  def sanitize_path(path)
    allowed_pattern = /\A[a-zA-Z0-9_\-\/]+(\.[a-zA-Z]+)?\z/
    if path.match?(allowed_pattern)
      path
    else
      raise ActionController::ForbiddenError(path, 'is not in a valid format')
    end
  end
end