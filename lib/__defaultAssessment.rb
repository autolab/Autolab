#
# {assessment}.rb - Autolab Assessment Configuration File
#
# This file is cached on the Autolab server.
#
# To make your changes go live: Assessment->Reload config file
# You can also upload a new config file from the assessment settings page.
#

module ##NAME_CAMEL##

  # List of hooks available:
  # ===================================
  # modifySubmissionScores
  #   brief: modify calculated scores for a submission
  #   params: scores, previous_submissions, problems
  #   returns: hash of problem names to problem scores, the new submission scores
  #   details: https://docs.autolabproject.com/lab/#overriding-modify-submission-score
  #
  # raw_score
  #   brief: modify how raw scores are calculated
  #   params: score (hash of problem names to problem scores)
  #   returns: float, score on this assessment excluding any penalties
  #   details: https://docs.autolabproject.com/instructors/#overriding-raw-score-calculations
  #
  # checkMimeType
  #   brief: reject files that are not of the correct type
  #   params: contentType (string), fileName (string)
  #   returns: boolean, true if the file is of the correct type, false otherwise
  #   details: https://docs.autolabproject.com/instructors/#customizing-submision-file-mime-type-check
  #
  # handout
  #   brief: provide a handout file for the assessment
  #   params: none
  #   returns: hash with keys "fullpath" (path to handout file relative to Rails.root), and "filename" (handout name)
  #   details: (undocumented)
  #
  # autogradeDone
  #   brief: provide a method to be called when autograding is done.
  #          This replaces the default behavior of saving feedback files and updating scores.
  #   params: submissions (array of Submission objects), feedback_str (string)
  #   returns: none
  #   details: (undocumented)
  #
  # listOptions
  #   brief: define items for the assessment's options menu
  #   params: list (hash of path to title)
  #   returns: hash of path to title
  #   details: (undocumented)
  #
  # scoreboardHeader
  #   brief: define the scoreboard header
  #   params: none
  #   returns: string, HTML for the header of the scoreboard
  #   details: (undocumented)
  #
  # createScoreboardEntry
  #   brief: create a row in the scoreboard
  #   params: scores (hash of problem names to problem scores), autoresult (string)
  #   returns: float array, the value for each column in the scoreboard for this entry
  #   details: (undocumented)
  #
  # scoreboardOrderSubmissions
  #   brief: define ordering for the scoreboard
  #   params: a (hash), b (hash)
  #           The hash contains the following keys: {:uid, :andrewID, :version, :time, :problems, :entry}
  #           where :entry is the scoreboard entry array
  #   returns: integer, -1 if a should be ranked higher, 1 if b should be ranked higher, 0 if they are tied
  #   details: (undocumented)
  #
  # autogradeInputFiles
  #   brief: define list of input files for the autograder
  #   params: ass_dir (Pathname)
  #   returns: array of hashes, the list of input files for the autograder
  #            The hash contains the following keys: {:localFile, :remoteFile, :destFile}
  #            - localFile: path to file on local machine
  #            - remoteFile: name of the file on the Tango machine
  #              If this file is unique per-submission (e.g. the student's code), then the filename should also be unique per-submission
  #              If undefined, value of localFile will be used instead
  #            - destFile: name of the file on the destination machine
  #   details: (undocumented)
  #
  # parseAutoresult
  #   brief: extract problem scores from the JSON autoresult string
  #   params: autoresult (string), _isOfficial (boolean)
  #           _isOfficial is true except for log submissions. If "Allow unofficial" is disabled, don't worry about this.
  #   returns: Hash of problem names to problems scores
  #   details: (undocumented)

end
