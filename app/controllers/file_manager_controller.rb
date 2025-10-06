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
    if (File.directory?(absolute_path) && check_instructor(absolute_path)) ||
       (path == "" && is_instructor_of_any_course)
      populate_directory(absolute_path, new_url)
      render 'file_manager/index'
    elsif File.file?(absolute_path) && check_instructor(absolute_path)
      # Check if this is a tar file and extract parameter is present
      if params[:extract] && is_tar_file?(absolute_path)
        # Skip extraction if the tar file itself is an executable
        if is_likely_executable?(absolute_path, File.basename(absolute_path))
          flash[:error] = "Cannot extract tar files that are not directories"
          redirect_to file_manager_index_path(path: File.dirname(path))
          return
        end

        begin
          parent_dir = File.dirname(absolute_path)
          # Create subdirectory for extraction based on tar filename without extension
          base_name = File.basename(absolute_path, '.*')
          # Remove additional extensions for files like .tar.gz
          base_name = base_name.gsub(/\.tar$/, '')
          extract_dir = File.join(parent_dir, base_name)

          # Ensure extract directory doesn't already exist to avoid conflicts
          counter = 1
          original_extract_dir = extract_dir
          while File.exist?(extract_dir)
            extract_dir = "#{original_extract_dir}_#{counter}"
            counter += 1
          end

          # Create the extraction directory
          FileUtils.mkdir_p(extract_dir)

          # Validate tar file before attempting extraction
          validate_tar_file(absolute_path)

          # Handle different tar formats
          if File.extname(absolute_path).downcase.in?(['.gz', '.tgz']) ||
             absolute_path.to_s.downcase.end_with?('.tar.gz')
            # Handle gzipped tar files
            require 'zlib'
            Zlib::GzipReader.open(absolute_path) do |gz|
              tar_extract_method = Gem::Package::TarReader.new(gz)
              extract_tar_entries(tar_extract_method, extract_dir)
            end
          else
            # Handle regular tar files - ensure proper resource management
            File.open(absolute_path, 'rb') do |file|
              tar_extract_method = Gem::Package::TarReader.new(file)
              extract_tar_entries(tar_extract_method, extract_dir)
            end
          end

          flash[:success] =
            "Successfully extracted #{File.basename(absolute_path)} to
              #{File.basename(extract_dir)}/"
          redirect_to file_manager_index_path(path: File.dirname(path))
          nil
        rescue Gem::Package::TarInvalidError => e
          # Clean up partially extracted directory
          FileUtils.rm_rf(extract_dir) if File.exist?(extract_dir)
          flash[:error] =
            "Corrupted tar file: #{e.message}. The file appears to be damaged or invalid."
          redirect_to file_manager_index_path(path: File.dirname(path))
          nil
        rescue Zlib::GzipFile::Error => e
          # Clean up partially extracted directory
          FileUtils.rm_rf(extract_dir) if File.exist?(extract_dir)
          flash[:error] = "Corrupted gzip archive: #{e.message}. The compressed file is damaged."
          redirect_to file_manager_index_path(path: File.dirname(path))
          nil
        rescue StandardError => e
          # Clean up partially extracted directory
          FileUtils.rm_rf(extract_dir) if File.exist?(extract_dir)
          flash[:error] = "Unable to extract tar file: #{e.message}"
          redirect_to file_manager_index_path(path: File.dirname(path))
          nil
        end
      elsif File.size(absolute_path) > 1_000_000 || params[:download]
        send_file absolute_path
      elsif !is_binary_file?(absolute_path)
        @path = path
        @file = absolute_path.read
        render :file, formats: :html
      else
        send_file(absolute_path,
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

      FileUtils.rm_rf(absolute_path)
    else
      flash[:error] = "You are not authorized to delete this"
      redirect_to root_path
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
        parent = new_path.split[0..-2].join('/')

        raise ArgumentError, "A file with that name already exists" if File.exist?(new_path)

        FileUtils.mkdir_p(parent)
        FileUtils.mv(absolute_path, new_path)
        flash[:success] = "Successfully renamed file to #{params[:new_name]}"
      end
    else
      flash[:error] = "You are not authorized to rename this path"
      redirect_to root_path
    end
  rescue ArgumentError => e
    flash[:error] = e.message
  end

  def chmod
    absolute_path = check_path_exist(params[:path])
    if check_instructor(absolute_path)
      if params[:permissions].nil? || params[:permissions].empty?
        raise ArgumentError, "Permissions not provided"
      end

      # Validate permission format (should be 3-4 digit octal)
      unless params[:permissions].match(/\A[0-7]{3,4}\Z/)
        raise ArgumentError,
              "Invalid permission format. Use 3-4 digit octal format (e.g., 755, 644)"
      end

      # Convert octal string to integer
      permission_mode = params[:permissions].to_i(8)

      # Validate permission range (0000 to 7777)
      unless permission_mode.between?(0, 0o7777)
        raise ArgumentError, "Permission value out of range"
      end

      # Apply the permission change
      File.chmod(permission_mode, absolute_path)
      flash[:success] = "Successfully changed permissions to #{params[:permissions]}"
    else
      flash[:error] = "You are not authorized to change permissions for this path"
      redirect_to root_path
    end
  rescue ArgumentError => e
    flash[:error] = e.message
    respond_to do |format|
      format.html { redirect_back(fallback_location: file_manager_index_path) }
      format.json { render json: { error: e.message }, status: :bad_request }
    end
  rescue Errno::EPERM, Errno::EACCES => e
    flash[:error] = "Permission denied: #{e.message}"
    respond_to do |format|
      format.html { redirect_back(fallback_location: file_manager_index_path) }
      format.json { render json: { error: "Permission denied: #{e.message}" }, status: :forbidden }
    end
  rescue StandardError => e
    flash[:error] = "Error changing permissions: #{e.message}"
    respond_to do |format|
      format.html { redirect_back(fallback_location: file_manager_index_path) }
      format.json {
        render json: { error: "Error changing permissions: #{e.message}" },
               status: :internal_server_error
      }
    end
  end

  def find_by_directory_path(absolute_path)
    # Normalize the path to ensure consistent comparison
    normalized_path = Pathname.new(absolute_path).cleanpath.to_s
    # Find course where the directory_path matches the given absolute path
    Course.find do |course|
      course.directory_path.to_s == normalized_path
    end
  end

  def find_by_folder_path(absolute_path)
    # Normalize the path to ensure consistent comparison
    normalized_path = Pathname.new(absolute_path).cleanpath.to_s

    # Find assessment where the folder_path matches the given absolute path
    Assessment.find do |assessment|
      assessment.folder_path.to_s == normalized_path
    end
  end

  def path_belongs_to_assessment?(absolute_path)
    find_by_folder_path(absolute_path)
  end

  def path_belongs_to_course?(absolute_path)
    find_by_directory_path(absolute_path)
  end

  def add_directory_to_tar(tar, dir_path, base_name = "")
    Dir.entries(dir_path).each do |entry|
      next if [".", ".."].include?(entry)

      full_path = File.join(dir_path, entry)
      tar_path = base_name.empty? ? entry : File.join(base_name, entry)
      mode = File.stat(full_path).mode
      if File.directory?(full_path)
        # Add directory entry
        tar.mkdir(tar_path, mode)
        # Recursively add directory contents
        add_directory_to_tar(tar, full_path, tar_path)
      elsif File.file?(full_path)
        # Add file entry
        File.open(full_path, 'rb') do |_file|
          tar.add_file(tar_path, mode) do |tar_file|
            tar_file.write(_file.read)
          end
        end
      elsif File.symlink?(full_path)
        # Add symbolic link
        target = File.readlink(full_path)
        tar.add_symlink(tar_path, target, mode)
      end
    end
  end

  def download_tar
    path = params[:path]&.split("/")&.drop(2)&.join("/")
    path = CGI.unescape(path)
    absolute_path = check_path_exist(path)
    if check_instructor(absolute_path)
      course = path_belongs_to_course?(absolute_path)
      assessment = path_belongs_to_assessment?(absolute_path)

      if course.present?
        tar_course = generate_tar(course)
        send_data tar_course.string.force_encoding("binary"),
                  filename: "#{course.name}.tar",
                  type: "application/x-tar",
                  disposition: "attachment"
      elsif assessment.present?
        tar_stream = StringIO.new("")
        Gem::Package::TarWriter.new(tar_stream) do |tar_assessment|
          assessment.name
          assessment.dump_yaml
          filter = []
          assessment.load_dir_to_tar(absolute_path.to_s, "", tar_assessment, filter, "")
        end
        tar_stream.rewind
        tar_stream.close
        send_data tar_stream.string.force_encoding("binary"),
                  filename: "#{assessment.name}.tar",
                  type: "application/x-tar",
                  disposition: "attachment"
      elsif File.file?(absolute_path)
        # Individual file - send directly without zipping
        send_file(absolute_path,
                  filename: File.basename(absolute_path),
                  disposition: 'attachment')
      elsif File.directory?(absolute_path)
        tar_stream = StringIO.new("")
        Gem::Package::TarWriter.new(tar_stream) do |tar|
          add_directory_to_tar(tar, absolute_path, File.basename(absolute_path))
        end
        tar_stream.rewind
        send_data tar_stream.string.force_encoding("binary"),
                  filename: "#{File.basename(absolute_path)}.tar",
                  type: "application/x-tar",
                  disposition: "attachment"
      else
        # Path exists but is neither a file nor directory (eg: symlink)
        send_file(absolute_path,
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
      else
        flash[:error] = "You are not authorized to upload files at this path"
        redirect_to root_path
      end
    end
  end

private

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
        permissions: begin
          sprintf('%o', stat.mode & 0o777)
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
    raise ActionController::RoutingError, 'Not Found' unless File.exist?(@absolute_path)

    @absolute_path
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

  def is_tar_file?(path)
    extension = File.extname(path).downcase
    extension == '.tar' ||
      extension == '.tgz' ||
      extension == '.gz' && path.to_s.downcase.end_with?('.tar.gz')
  end

  def extract_tar_entries(tar_reader, extract_dir)
    tar_reader.rewind
    tar_reader.each do |entry|
      # Skip entries with invalid names or paths that try to escape the extraction directory
      next if entry.full_name.include?('..')
      next if entry.full_name.start_with?('/')

      # Handle entries that might be at the root level or in subdirectories
      target_path = File.join(extract_dir, entry.full_name)

      if entry.directory?
        FileUtils.mkdir_p(target_path)
      elsif entry.file?
        # Ensure parent directory exists (especially important for files at root level)
        parent_dir = File.dirname(target_path)
        FileUtils.mkdir_p(parent_dir) unless parent_dir == extract_dir

        # Properly read and write file data to prevent corruption
        File.open(target_path, 'wb') do |f|
          # Read in chunks to handle large files properly and detect corruption
          bytes_written = 0
          expected_size = entry.header.size

          begin
            while (chunk = entry.read(8192))
              break if chunk.empty?

              f.write(chunk)
              bytes_written += chunk.length

              # Safety check to prevent infinite loops with corrupted entries
              if bytes_written > expected_size + 8192
                raise "File size mismatch: expected #{expected_size}, got #{bytes_written}+"
              end
            end
          rescue StandardError => e
            # If reading fails, try to read the entire content at once as fallback
            Rails.logger.warn "Chunked reading failed for #{entry.full_name}:
              #{e.message}, trying full read"
            begin
              entry.rewind
              content = entry.read
              f.rewind
              f.truncate(0)
              f.write(content)
              bytes_written = content.length
            rescue StandardError => fallback_error
              raise "Failed to extract #{entry.full_name}: #{fallback_error.message}"
            end
          end

          # Verify file size matches expected size
          if expected_size > 0 && bytes_written != expected_size
            Rails.logger.warn "Size mismatch for #{entry.full_name}:
              expected #{expected_size}, got #{bytes_written}"
          end
        end

        # Handle file permissions, especially for executables
        begin
          mode = entry.header.mode
          if mode.is_a?(Integer) && mode > 0 && mode < 0o777777
            # Preserve original permissions
            File.chmod(mode, target_path)
          elsif is_likely_executable?(target_path, entry.full_name)
            # Determine if this should be executable based on file characteristics
            File.chmod(0o755, target_path)
          # Set executable permissions (owner: rwx, group: rx, other: rx)
          else
            # Set default readable permissions for regular files
            File.chmod(0o644, target_path)
          end
        rescue StandardError => e
          # Log the error but continue extraction
          Rails.logger.warn "Could not set permissions for #{target_path}: #{e.message}"

          # Fallback: try to determine if it should be executable
          if is_likely_executable?(target_path, entry.full_name)
            begin
              File.chmod(0o755, target_path)
            rescue StandardError
              File.chmod(0o644, target_path)
            end
          else
            File.chmod(0o644, target_path)
          end
        end
      elsif entry.symlink?
        # Handle symbolic links if present
        begin
          File.symlink(entry.header.linkname, target_path)
        rescue StandardError => e
          Rails.logger.warn "Could not create symlink #{target_path}: #{e.message}"
        end
      end
    end
  end

  def is_likely_executable?(file_path, original_name)
    # Check file extension for common executable types
    executable_extensions = ['.exe', '.bin', '.run', '.sh', '.bash', '.zsh', '.py', '.pl', '.rb',
                             '.jar', '.out']
    extension = File.extname(original_name).downcase
    return true if executable_extensions.include?(extension)

    # Check for common executable names without extensions
    executable_names = ['makefile', 'dockerfile', 'configure', 'install', 'setup', 'build',
                        'autograde']
    base_name = File.basename(original_name).downcase
    # return true if any executable names is in the base_name
    return true if executable_names.any? { |name| base_name.include?(name) }

    # Check if filename has no extension and is not a common non-executable file
    if extension.empty? && !original_name.include?('.')
      # Common non-executable files without extensions
      non_executable_names = ['readme', 'license', 'changelog', 'authors', 'contributors', 'todo',
                              'news']
      return false if non_executable_names.include?(base_name)

      # If it's not a known non-executable, assume it might be executable
      return true
    end

    # Check file content for executable signatures (if file exists and is readable)
    begin
      if File.exist?(file_path) && File.readable?(file_path) && File.size(file_path) > 0
        # Read first few bytes to check for executable signatures
        first_bytes = File.read(file_path, [File.size(file_path), 16].min)

        # ELF executable (Linux/Unix)
        return true if first_bytes.start_with?("\x7fELF")

        # Mach-O executable (macOS) - multiple signatures
        return true if first_bytes.start_with?("\xfe\xed\xfa\xce") # 32-bit
        return true if first_bytes.start_with?("\xfe\xed\xfa\xcf") # 64-bit
        return true if first_bytes.start_with?("\xcf\xfa\xed\xfe") # reverse byte order

        # PE executable (Windows)
        return true if first_bytes.start_with?("MZ")

        # Script with shebang
        return true if first_bytes.start_with?("#!")

        # Java class files
        return true if first_bytes.start_with?("\xca\xfe\xba\xbe")

        # Archive files that might contain executables
        return true if first_bytes.start_with?("PK") && extension.empty? # ZIP-based executable
      end
    rescue StandardError => e
      # If we can't read the file, fall back to name-based detection
      Rails.logger.debug "Could not read file for executable detection: #{e.message}"
    end

    false
  end

  # Validate tar file integrity before extraction
  def validate_tar_file(file_path)
    # Check if file is readable and has content
    raise "Tar file is empty or unreadable" unless File.readable?(file_path) &&
                                                   File.size(file_path) > 0

    # Validate based on file extension
    if File.extname(file_path).downcase.in?(['.gz', '.tgz']) ||
       file_path.to_s.downcase.end_with?('.tar.gz')
      # Validate gzipped tar file
      begin
        require 'zlib'
        Zlib::GzipReader.open(file_path) do |gz|
          # Try to read the first tar header to validate format
          tar_reader = Gem::Package::TarReader.new(gz)
          tar_reader.rewind
          # Just peek at the first entry to validate the format
          first_entry = tar_reader.first
          raise "Invalid tar format: no valid entries found" if first_entry.nil?
        end
      rescue Zlib::GzipFile::Error => e
        raise "Corrupted gzip file: #{e.message}"
      rescue Gem::Package::TarInvalidError => e
        raise "Invalid tar format: #{e.message}"
      end
    else
      # Validate regular tar file
      begin
        File.open(file_path, 'rb') do |file|
          tar_reader = Gem::Package::TarReader.new(file)
          tar_reader.rewind
          # Just peek at the first entry to validate the format
          first_entry = tar_reader.first
          raise "Invalid tar format: no valid entries found" if first_entry.nil?
        end
      rescue Gem::Package::TarInvalidError => e
        raise "Invalid tar format: #{e.message}"
      rescue StandardError => e
        raise "Error reading tar file: #{e.message}"
      end
    end
  end
end
