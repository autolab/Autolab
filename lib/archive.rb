require 'rubygems'
require 'rubygems/package'
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
      pathname = entry.respond_to?(:full_name) ? entry.full_name : entry.name

      files << {
        pathname: pathname,
        header_position: i,
        mac_bs_file: pathname.include?("__MACOSX") ||
                     pathname.include?(".DS_Store") ||
                     pathname.include?(".metadata"),
        directory: File.directory?(pathname)
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
      pathname = entry.respond_to?(:full_name) ? entry.full_name : entry.name

      next if pathname.include? "__MACOSX" or
        pathname.include? ".DS_Store" or
        pathname.include? ".metadata"
      
      if i == n then
        if File.directory?(pathname) then
          res = nil, pathname
        elsif entry.respond_to?(:read) then # tar and tgz
          res = entry.read, entry.full_name
        else # zip
          res = entry.get_input_stream.read, entry.name
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

  def self.is_archive?(filename)
    archive_type = get_archive_type(filename)
    return (archive_type.include?("tar") || archive_type.include?("gzip") || archive_type.include?("zip"))
  end

  def self.get_archive_type(filename)
    IO.popen(["file", "--brief", "--mime-type", filename], in: :close, err: :close) { |io| io.read.chomp }
  end

  def self.get_archive(filename, archive_type)
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

end
