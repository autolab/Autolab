require "rubygems"
require "rubygems/package"
require "tempfile"
require "zlib"
require "zip"

##
# This module provides functionality for dealing with Archives, including zips,
# tars, and gunzipped tars
#
module Archive
  def self.get_files(archive_path)
    archive_type = get_archive_type(archive_path)
    archive_extract = get_archive(archive_path, archive_type)

    files = []

    # Parse archive header
    archive_extract.each_with_index do |entry, i|
      # Obtain path name depending for tar/zip entry
      pathname = get_entry_name(entry)

      files << {
        pathname: pathname,
        header_position: i,
        mac_bs_file: pathname.include?("__MACOSX") ||
          pathname.include?(".DS_Store") ||
          pathname.include?(".metadata") ||
          File.basename(pathname).start_with?('.'),
        directory: looks_like_directory?(pathname)
      }
    end

    archive_extract.close

    files
  end

  def self.recoverHierarchy(files, root)
    depth = root[:pathname].chomp("/").count "/"
    if(root[:pathname] == "")
      depth = -1
    end
    if(!root[:directory])
      return root
    end
    subFiles = []
    filesNestedSomewhere = files.select{|entry| entry[:pathname].start_with?(root[:pathname]) && !(entry[:pathname] == root[:pathname])}
    for file in filesNestedSomewhere
      fileDepth = file[:pathname].chomp("/").count "/"
      if(fileDepth == depth+1)
        subFiles << recoverHierarchy(filesNestedSomewhere, file)
      end
    end
    subFiles.sort! { |a, b| a[:header_position] <=> b[:header_position] }
    root[:subfiles] = subFiles
    return root
  end

  # given a list of files, sanitize and create
  # missing file directories
  def self.sanitize_directories(files)

    cleaned_files = []
    file_path_set = Set[]
    
    # arbitrary header positions for the new directories
    starting_header = -1

    # add pre-existing directories to the set
    for file in files

      # edge case for removing "./" from pathnames
      if file[:pathname].include?("./")
        file[:pathname] = file[:pathname].split("./")[1]
      end

      if(file[:directory])
        file_path_set.add(file[:pathname])
      end
    end

    for file in files
      # for each file, check if each of its directories and subdir
      # exist. If it does not, create and add them
      if(!file[:directory])
        paths = file[:pathname].split("/")
        for i in 1..(paths.size - 1) do
          new_path = paths[0,paths.size-i].join("/") + "/"
          if(!file_path_set.include?(new_path))
            cleaned_files.append({
              :pathname=>new_path,
              :header_position=>starting_header,
              :mac_bs_file=>false,
              :directory=>true
            })
            starting_header = starting_header - 1
            file_path_set.add(new_path)
          end
        end 
      end
      
      # excludes "./" paths
      if(file[:pathname]!=nil)
        cleaned_files.append(file)
      end
    end

    cleaned_files
  end

  def self.get_file_hierarchy(archive_path)
    files = get_files(archive_path)
    files = sanitize_directories(files)
    res = recoverHierarchy(files, {pathname: "", directory: true})
    return res[:subfiles]
  end

  def self.get_nth_file(archive_path, n)
    archive_type = get_archive_type(archive_path)
    archive_extract = get_archive(archive_path, archive_type)

    # Parse archive header
    res = nil, nil
    archive_extract.each_with_index do |entry, i|
      # Obtain path name depending for tar/zip entry
      pathname = get_entry_name(entry)

      next if pathname.include?("__MACOSX") ||
              pathname.include?(".DS_Store") ||
              pathname.include?(".metadata") ||
              i != n

      if looks_like_directory?(pathname)
        res = nil, pathname
      else
        res = read_entry_file(entry), get_entry_name(entry)
      end
      break
    end

    archive_extract.close

    res
  end

  def self.get_nth_filename(files, n)
    files[n][:pathname]
  end

  def self.get_archive_type(filename)
    IO.popen(["file", "--brief", "--mime-type", filename], in: :close, err: :close) do |io|
      io.read.chomp
    end
  end

  def self.archive?(filename)
    return nil unless filename
    archive_type = get_archive_type(filename)
    (archive_type.include?("tar") || archive_type.include?("gzip") || archive_type.include?("zip"))
  end

  def self.get_archive(filename, archive_type = nil)
    archive_type = get_archive_type(filename) if archive_type.nil?

    if archive_type.include? "tar"
      archive_extract = Gem::Package::TarReader.new(File.new(filename))
      archive_extract.rewind # The extract has to be rewinded after every iteration
    elsif archive_type.include? "gzip"
      archive_extract = Gem::Package::TarReader.new(Zlib::GzipReader.open(filename))
      archive_extract.rewind
    elsif archive_type.include? "zip"
      archive_extract = Zip::File.open(filename)
    else
      fail "Unrecognized archive type!"
    end
    archive_extract
  end

  def self.get_entry_name(entry)
    # tar/tgz vs zip
    name = entry.respond_to?(:full_name) ? entry.full_name : entry.name
    if ! name.ascii_only?
      name = String.new(name)
      name.force_encoding("UTF-8")
      if ! name.valid_encoding?
        # not utf-8. Assume single byte and choose windows western, since
        # iso8859-1 printables are a subset
        name.force_encoding("Windows-1252")
        name.encode!()
      end
    end
    name
  end

  def self.read_entry_file(entry)
    # tar/tgz vs zip
    entry.respond_to?(:read) ? entry.read : entry.get_input_stream.read
  end

  ##
  # returns a zip archive containing every file in the given path array
  #
  def self.create_zip(paths)
    return nil if paths.nil? || paths.empty?

    Tempfile.open(["submissions", ".zip"]) do |t|
      Zip::File.open(t.path, Zip::File::CREATE) do |z|
        paths.each { |p| z.add(File.basename(p), p) }
        z
      end
      t
    end
    # the return value should be the return value of the outer block, which is the tempfile
  end

  def self.looks_like_directory?(pathname)
    pathname.ends_with?("/")
  end
end
