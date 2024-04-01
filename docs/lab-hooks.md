# Lab Hooks

This document provides a summary of all the lab (aka assessment) hooks available to an instructor.

Lab hooks are defined in the lab's configuration file, `<labname>.rb`. The configuration file is located in the lab's directory, at the path `<coursename>/<labname>/<labname>.rb`.

To make changes live, you must select the "Reload config file" option on the lab's index page. You can also upload a new config file from the lab's setting page.

To debug the hooks, you can make use of the `ASSESSMENT_LOGGER.log(<expr>)` method to print output into the lab's `log.txt` file.

!!! Danger "Function Arity"
    When defining the hooks below, be sure that they take the correct number of arguments.
    Failure to do so might leave your assessment in a hard-to-recover state. 

## Modify Submission Score

Hook: `modifySubmissionScores`

By default, the scores output by the autograder will be directly assigned to the individual problem scores. This hook allows you to override the score calculation for a lab.

```ruby
def assessmentVariables
    variables = {}
    variables["previous_submissions_lookback"] = 1000
    variables["exclude_autograding_in_progress_submissions"] = false
    variables
end

def modifySubmissionScores(scores, previous_submissions, problems)

  scores["Score1"] = -(previous_submissions.length)
  
  # Get Score1 score for previous submission
  scores["Score2"] = previous_submissions[0].scores.find_or_initialize_by(:problem_id => problems.find_by(:name => "Score1").id).score

  # Get Score2 score for previous submission
  scores["Score3"] = previous_submissions[0].scores.find_or_initialize_by(:problem_id => problems.find_by(:name => "Score2").id).score
  
  scores
end
```
The code snippet above allows you to create a lab that has a score that is a function of the number of previous submissions, and the scores of previous submissions. This particular lab has four problems called "Autograded Score", "Score1", "Score2", "Score3". It assigns the score of "Score1" to be the negative of the number of previous submissions, and the score of "Score2" to be the score of "Score1" of the previous submission, and the score of "Score3" to be the score of "Score2" of the previous submission.

There are two settings that you can change in the `assessmentVariables` function that will affect the behavior of the `modifySubmissionScores` function:

- `previous_submissions_lookback`: The number of previous submissions to look back when calculating the score. By default, it is set to 1000.
- `exclude_autograding_in_progress_submissions`: If set to `true`, the submissions that are currently being autograded will be excluded when passed into the `modifySubmissionScores` function. By default, it is set to `false`.

The three arguments passed into the `modifySubmissionScores` function are:

- `scores`: A hash that maps the problem name to the score.
- `previous_submissions`: A list of previous submissions, sorted by submission time in descending order, it is an ActiveRecord object.
- `problems`: A list of problems in the lab, it is an ActiveRecord object.

For more information on how to use ActiveRecord, please refer to the [ActiveRecord documentation](http://guides.rubyonrails.org/active_record_querying.html). For the schema of the `Submission` and `Problem` models, please refer to the [Autolab Schema](https://github.com/autolab/Autolab/blob/master/db/schema.rb).

## Raw Score Calculations

Hook: `raw_score`

By default, the raw score for a submission is the sum of the individual problem scores. This hook allows you to override the raw score calculation for a lab.

```ruby
def raw_score(score)
    perfindex = score["Autograded Score"].to_f()
    heap = score["Heap Checker"].to_f()
    style = score["Style"].to_f()
    deduct = score["CorrectnessDeductions"].to_f()
    perfpoints = perfindex

    # perfindex below 50 gets autograded score of 0.
    if perfindex < 50.0 then
        perfpoints = 0
    else
        perfpoints = perfindex
    end

    return perfpoints + heap + style + deduct
end
```

This particular lab has four problems called "Autograded Score", "Heap Checker", "Style", and "CorrectnessDeductions". The code snippet above sets an "Autograded Score" of less than 50 to 0 when the raw score is calculated.

## Submission File MIME Type Check

Hook: `checkMimeType`

By default, Autolab does not perform MIME type check for submission files. This hook allows you to define a MIME type check method. For example, to prevent students from submitting a binary file to the assessment, you might add the following `checkMimeType` function:

```ruby
def checkMimeType(contentType, fileName)
    return contentType != "application/octet-stream"
end
```

As of now, the only way to provide a more informative message to students is to raise an error:

```ruby
def checkMimeType(contentType, fileName)
    raise "Do not submit binary files!" if contentType == "application/octet-stream"
    
    return true
end
```

This results in the following error message being displayed to students when they attempt to submit binary files.

![MIME Type Check](/images/mime_type_check.png)

Alternatively, you can use the file name to do file type checks. The following snippet prevents students from submitting python files:

```ruby
def checkMimeType(contentType, fileName)
    return fileName.split(".")[-1] != "py"
end
```

Note that this function does not have access to Rails controller attributes such as `flash` or `params`. Attempts to access what's beyond the arguments passed to the function will result in an error.

## Lab Handout

Hook: `handout`

By default, the handout provided to students when they click on "Download handout" is the file path or URL specified in the lab settings. This hook allows you to run custom code when the button is clicked and then return a path to the handout. This can be useful in creating customized handouts on a per-student basis.

!!! info "Restrictions on Handout Path"
    For security reasons, the handout path returned by the hook must reside within the lab folder.

```ruby
def handout
    course = @assessment.course.name
    asmt = @assessment.name
    file = "autograde-Makefile"
    
    file_path = "courses/#{course}/#{asmt}/#{file}"
    filename = "makefile"
    Hash["fullpath", file_path, "filename", filename]
end
```

The code snippet above downloads the `autograde-Makefile` (assuming it resides at the root of the lab directory) as the file `makefile`.

## On Autograde Completion

Hook: `autogradeDone`

By default, upon autograding completion, the feedback is saved to the feedback file and submission(s) scores are updated, amongst other things.

This hook allows you to override this behavior. Unless you know what you're doing, you should probably leave this hook alone.

```ruby
def autogradeDone(submissions, feedback)
    # submissions: all the submissions connected to this feedback (could be multiple if this was a group submission)
    # feedback: feedback string from the autograder
    
    # default behavior - write feedback into feedback file
    
    saveAutograde(submissions, feedback) # you should probably call this
end
```

## List Options

Hook: `listOptions`

By default, the following options are displayed to students when viewing an assessment:

- View handin history
- View writeup (if the assessment has a writeup defined)
- Download handout (if the assessment has a handout defined)
- Group options (if the assessment has groups enabled)
- View scoreboard (if the assessment has a scoreboard)

This hook allows you to disable the display of these options and/or display your own options.

!!! info "Only affects the dropdown"
    Even if certain options are hidden from the "Options" dropdown through this hook,
    students can still navigate directly to the corresponding pages if they so wish. 

```ruby
def listOptions(list)
    # The default options are: history, writeup, handout, groups, scoreboard
    # Delete the options that you do not want to show
    list.delete("history") # hides "View handin history"
    
    # You can display your own options
    # list[<key>] = <value> where <key> is the url route and <value> is the text to display for the option
    # (Non-exhaustive) possible values for <key>: history, writeup, handout
    list["history"] = "View your official scores"
    list["writeup"] = "View the writeup"
    list["handout"] = "Download your bomb"
    
    # Avoid setting custom keys to a value of nil, as that is how the code distinguishes default options.
    return list
end
```

The code snippet above hides the default option "View handin history" and defines three custom options `history`, `writeup`, and `handout`.
In particular, the link to `history` now has the text "View your official scores".

!!! info "Valid keys for options"
    Other than `history`, `writeup`, and `handout`, a valid key could technically be any route associated with assessments.
    However, many of these routes are not visible to students and it would not make sense to list them.

    For this reason, the following keys are explicitly ignored (but this is not comprehensive):
    `edit`, `viewGradesheet`, `reload`

    Invalid keys will be marked as such.

## Scoreboard Header

Hook: `scoreboardHeader`

By default, the scoreboard header follows the following format:

- If a [custom column specification](/features/scoreboards/#custom-scoreboards) is provided: `Rank`, `Nickname`, `Version`, `Time`, followed by the columns defined in the column specification
- Otherwise: `Rank`, `Nickname`, `Version`, `Time`, `Total`, followed by the name of each problem in the assessment

This hook allows for even greater flexibility in the definition of the scoreboard header.
If defined, it takes precedence over a custom column specification.

!!! info "Restrictions on HTML tags"
    Only `th` and `td` tags can be used, all other tags will be stripped.

```ruby
def scoreboardHeader
    "<th>Nickname</th><th>Version</th><th>Time</th><th>Total</th><th>Problem 1</th><th>Problem 2</th>"
end
```

The code snippet above defines a scoreboard whose header consists of the fields `Rank`, `Nickname`, `Version`, `Time`, `Total`, `Problem 1`, `Problem 2`.

Thus, other than the `Rank` column, the number of columns and their names can be fully customized.

## Scoreboard Entries

Hook: `createScoreboardEntry`

By default, each scoreboard row, corresponding to a user, follows the following format: `Rank`, `Nickname`, `Version`, `Time`, `Total`, followed by the score for each problem in the assessment.

This hook allows for greater flexibility in the values displayed for each student.
In particular, the values displayed for the columns beyond `Rank`, `Nickname`, `Version`, and `Time` can be configured.
This hook should most likely be used in conjunction with the `scoreboardHeader` hook or a [custom column specification](/features/scoreboards/#custom-scoreboards).

```ruby
def createScoreboardEntry(scores, autoresult)
    defused = 0
    explosions = 0
    scores.each_pair do |name, value|
        if name == "explosion"
            explosions = value.to_i()
        else
            defused += value.to_i()
        end
    end
    totalscore = raw_score(scores)
    [defused, explosions, totalscore]
end
```

Assuming a suitable `raw_score` method is defined, the code snippet above displays a student's score,
together with statistics such as the value associated with the problem `explosion` and the sum of values associated
with the other problems.

## Scoreboard Ordering

Hook: `scoreboardOrderSubmissions`

By default, scoreboard rows are sorted as follows:

- If a [custom column specification](/features/scoreboards/#custom-scoreboards) is provided (and an autograder is defined): Sort the columns from left to right in descending/ascending order (depending on the column specification) 
- Otherwise: Sort by decreasing total score, followed by increasing submission time

This hook allows for greater flexibility in the sorting logic.

```ruby
# The hash contains the following keys:
# {:nickname, :andrewID, :fullName, :problems, :time, :version, :autoresult, :entry}
# where :entry is the scoreboard entry array returned by createScoreboardEntry
def scoreboardOrderSubmissions(a, b)
    # In this example, assume that each entry has the format [defused, explosions, totalscore]

    # Entry A ranks higher than entry B if it has more defused phases.
    rank = -(a[:entry][0] <=> b[:entry][0])
    if rank != 0
        return rank
    end

    # If defused phases are equal, entry A ranks higher than entry
    # B if it has _fewer_ explosions.
    rank = a[:entry][1] <=> b[:entry][1]
    if rank != 0
        return -rank
    end

    # As a final tiebreaker, earlier submissions rank higher.
    -(a[:time] <=> b[:time])
end
```

The code snippet above sorts by the first column (`defused`) in decreasing order, followed by the second column (`explosions`) in increasing order. As a final tiebreaker, it sorts by time.

## Autograding Input Files

Hook: `autogradeInputFiles`

By default, the following autograding input files are sent to Tango

1. The student's handin file
2. The makefile that runs the process
3. The tarfile with all of the files needed by the autograder

This hook allows you to define a custom list of input files to be sent instead.

```ruby
def autogradeInputFiles(ass_dir, assessment, submission)
    local_handin = submission.handin_file_path
    remote_handin = submission.handin_file_long_filename
    dest_handin = assessment.handin_filename
    
    # localFile: path to file on local machine
    # remoteFile: name of the file on the Tango machine
    # - if this file is unique per-submission (e.g. student's code), then the filename should also be unique per-submission
    #   so as to avoid name-collisions
    # - if undefined, value of localFile will be used instead
    # destFile: name of the file on the destination machine (e.g. docker container)
    
    handin = {
            "localFile" => local_handin,
            "remoteFile" => remote_handin,
            "destFile" => dest_handin
    }
    
    [handin] # and any other files required
end
```

## Autoresult Parsing

Hook: `parseAutoresult`

By default, the autoresult string from the autograder (the last non-empty line) is assumed to be encoded in JSON and is parsed as such.
If a different format is used for the autoresult string, this hook allows you to define custom parsing logic.

```ruby
# _isOfficial is true except for log submissions
# If "Allow unofficial" is disabled, don't worry about this.
def parseAutoresult(autoresult, _isOfficial)
    # Return a hash of problem name to scores
    { "Problem 1": 1, "Problem 2": 2, "Problem 3": 3, "Problem 4": 4, "Problem 5": 5, "Problem 6": 6 }
end
```