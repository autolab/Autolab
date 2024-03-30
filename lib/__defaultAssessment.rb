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
  #   params: scores (hash of problem names to problem scores),
  #           previous_submissions (array of ActiveRecord Submission objects),
  #           problems (array of ActiveRecord Problem objects)
  #   returns: hash of problem names to problem scores, the new submission scores
  #   details: https://docs.autolabproject.com/lab-hooks/#modify-submission-score
  #
  # raw_score
  #   brief: modify how raw scores are calculated
  #   params: score (hash of problem names to problem scores)
  #   returns: float, score on this assessment excluding any penalties
  #   details: https://docs.autolabproject.com/lab-hooks/#raw-score-calculations
  #
  # checkMimeType
  #   brief: reject files that are not of the correct type
  #   params: contentType (string), fileName (string)
  #   returns: boolean, true if the file is of the correct type, false otherwise
  #   details: https://docs.autolabproject.com/lab-hooks/#submission-file-mime-type-check
  #
  # handout
  #   brief: provide a handout file for the assessment
  #   params: none
  #   returns: hash with keys "fullpath" (path to handout file relative to Rails.root), and "filename" (handout name)
  #   details: https://docs.autolabproject.com/lab-hooks/#lab-handout
  #
  # autogradeDone
  #   brief: provide a method to be called when autograding is done.
  #          This replaces the default behavior of saving feedback files and updating scores.
  #   params: submissions (array of Submission objects), feedback_str (string)
  #   returns: none
  #   details: https://docs.autolabproject.com/lab-hooks/#on-autograde-completion
  #
  # listOptions
  #   brief: define items for the assessment's options menu
  #   params: list (hash of path to title)
  #   returns: hash of path to title
  #   details: https://docs.autolabproject.com/lab-hooks/#list-options
  #
  # scoreboardHeader
  #   brief: define the scoreboard header
  #   params: none
  #   returns: string, HTML for the header of the scoreboard
  #   details: https://docs.autolabproject.com/lab-hooks/#scoreboard-header
  #
  # createScoreboardEntry
  #   brief: create a row in the scoreboard
  #   params: scores (hash of problem names to problem scores), autoresult (string)
  #   returns: float array, the value for each column in the scoreboard for this entry
  #   details: https://docs.autolabproject.com/lab-hooks/#scoreboard-entries
  #
  # scoreboardOrderSubmissions
  #   brief: define ordering for the scoreboard
  #   params: a (hash), b (hash)
  #           The hash contains the following keys: {:nickname, :andrewID, :fullName, :problems, :time, :version, :autoresult, :entry}
  #           where :entry is the scoreboard entry array
  #   returns: integer, -1 if a should be ranked higher, 1 if b should be ranked higher, 0 if they are tied
  #   details: https://docs.autolabproject.com/lab-hooks/#scoreboard-ordering
  #
  # autogradeInputFiles
  #   brief: define list of input files for the autograder
  #   params: ass_dir (Pathname),
  #           assessment (ActiveRecord Assessment object),
  #           submission (ActiveRecord Submission object)
  #   returns: array of hashes, the list of input files for the autograder
  #            The hash contains the following keys: {:localFile, :remoteFile, :destFile}
  #            - localFile: path to file on local machine
  #            - remoteFile: name of the file on the Tango machine
  #              If this file is unique per-submission (e.g. the student's code), then the filename should also be unique per-submission
  #              If undefined, value of localFile will be used instead
  #            - destFile: name of the file on the destination machine
  #   details: https://docs.autolabproject.com/lab-hooks/#autograding-input-files
  #
  # parseAutoresult
  #   brief: extract problem scores from the JSON autoresult string
  #   params: autoresult (string), _isOfficial (boolean)
  #           _isOfficial is true except for log submissions. If "Allow unofficial" is disabled, don't worry about this.
  #   returns: Hash of problem names to problems scores
  #   details: https://docs.autolabproject.com/lab-hooks/#autoresult-parsing

end
