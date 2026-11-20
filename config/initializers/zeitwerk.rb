# These legacy modules are explicitly loaded by AssessmentsController and do not
# follow Zeitwerk's namespace conventions (e.g. handin.rb defines AssessmentHandin).
Rails.autoloaders.main.ignore(Rails.root.join("app/controllers/assessment"))

# This legacy file defines global logger instances as well as several classes.
# Load it once so the globals exist in development and survive code reloads.
Rails.autoloaders.main.ignore(Rails.root.join("app/models/course_logger.rb"))
require Rails.root.join("app/models/course_logger")
