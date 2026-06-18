module CourseTransfer
  # Base error for all course-transfer failures.
  class Error < StandardError; end
  class ExportError < Error; end
  class ImportError < Error; end
  class FileTransferError < Error; end

  class UnknownExporter < ExportError; end
  class DuplicateExporter < ExportError; end
  class MissingExportReference < ExportError; end
  class DuplicateNaturalKey < ExportError; end

  class CyclicImportDependencies < ImportError; end
  class InvalidPackage < ImportError; end
  class MissingImportReference < ImportError; end
  class ImportCollision < ImportError; end
  class ImportValidationError < ImportError; end
  class InvalidCourseIdentifier < ImportError; end
end
