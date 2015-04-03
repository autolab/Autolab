##
# Provides PDF functionality, which is mostly testing if files are pdfs
#
module PDF
  def self.pdf?(file)
    return false unless file
    # all PDFs have '%PDF-<major-version>.<minor-version>' in them somewhere.
    # this is used instead of MIME type detection because it should work
    # for PDFs inside of Archives as well.
    # the scrub call prevents invalid byte sequence errors.
    (file.scrub("*") =~ /\%PDF-\d+\.?\d+/)
  end
end
