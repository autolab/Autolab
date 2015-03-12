require 'rubygems'
require 'rubygems/package'
require 'tempfile'
require 'zlib'
require 'zip'

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
                     pathname.include?(".metadata"),
        directory: looks_like_directory?(pathname)
      }
    end

    archive_extract.close

    files
  end

  def self.get_nth_file(archive_path, n)
    archive_type = get_archive_type(archive_path)
    archive_extract = get_archive(archive_path, archive_type)

    # Parse archive header
    res = nil, nil
    archive_extract.each_with_index do |entry, i|
      # Obtain path name depending for tar/zip entry
      pathname = get_entry_name(entry) 

      next if pathname.include? "__MACOSX" or
        pathname.include? ".DS_Store" or
        pathname.include? ".metadata"
      
      if i == n then
        if looks_like_directory?(pathname) then
          res = nil, pathname
        else
          res = read_entry_file(entry), get_entry_name(entry)
        end
        break
      end
    end

    archive_extract.close

    return res
  end

  def self.get_nth_filename(files, n)
    files[n][:pathname]
  end

  def self.get_archive_type(filename)
    IO.popen(["file", "--brief", "--mime-type", filename], in: :close, err: :close) { |io| io.read.chomp }
  end

  def self.is_archive?(filename)
    return nil unless filename
    archive_type = get_archive_type(filename)
    return (archive_type.include?("tar") || archive_type.include?("gzip") || archive_type.include?("zip"))
  end

  def self.get_archive(filename, archive_type = nil)
    if archive_type == nil then
      archive_type = get_archive_type(filename)
    end

    if archive_type.include? "tar" then
      archive_extract = Gem::Package::TarReader.new(File.new(filename))
      archive_extract.rewind # The extract has to be rewinded after every iteration
    elsif archive_type.include? "gzip" then
      archive_extract = Gem::Package::TarReader.new(Zlib::GzipReader.open(filename))
      archive_extract.rewind
    elsif archive_type.include? "zip" then
      archive_extract = Zip::File.open(filename)
    else
      raise "Unrecognized archive type!"
    end
    archive_extract
  end

  def self.get_entry_name(entry)
    # tar/tgz vs zip
    entry.respond_to?(:full_name) ? entry.full_name : entry.name
  end

  def self.read_entry_file(entry)
    # tar/tgz vs zip
    entry.respond_to?(:read) ? entry.read : entry.get_input_stream.read
  end

  ##
  # returns a zip archive containing every file in the given path array
  #
  def self.create_zip(paths)
    if paths.nil? || paths.empty?
      return nil
    end

    Tempfile.open(['submissions', '.zip']) do |t|
      Zip::File.open(t.path, Zip::File::CREATE) do |z|
        paths.each { |p| z.add(File.basename(p), p) }
        z
      end
      t
    end
    # the return value should be the return value of the outer block, which is the tempfile
  end

  def self.looks_like_directory?(pathname)
    return pathname.ends_with?("/")
  end

end
