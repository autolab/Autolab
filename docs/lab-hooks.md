# Lab Hooks

This document provides a summary of all the lab (aka assessment) hooks available to an instructor.

Lab hooks are defined in the lab's configuration file, `<labname>.rb`. The configuration file is located in the lab's directory, `<coursename>/<labname>/<labname>.rb`.

To make changes live, you must select the "Reload config file" option on the lab's index page. You can also upload a new config file from the lab's setting page.

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

This particular lab has four problems called "Autograded Score", "Heap Checker", "Style", and "CorrectnessDeductions". An "Autograded Score" less than 50 is set to zero when the raw score is calculated.

## Customizing Submission File MIME Type Check

Hook: `checkMimeType`

By default, Autolab does not perform MIME type check for submission files. This hook allows you to define a MIME type check method. For example, to prevent students from submitting a binary file to the assessment, you might add the following `checkMimeType` function:

```ruby
def checkMimeType(contentType, fileName)
    return contentType != "application/octet-stream"
end
```

As of now, the only way to provide a more informative message to student is to raise an error:

```ruby
def checkMimeType(contentType, fileName)
    raise "Do not submit binary files!" if contentType == "application/octet-stream"
    
    return true
end
```

This results in the following error message to students when they attempt to submit binary files.

![MIME Type Check](/images/mime_type_check.png)

Alternatively, you can use the file name to do file type check. The following snippet prevents students from submitting python files:

```ruby
def checkMimeType(contentType, fileName)
    return fileName.split(".")[-1] != "py"
end
```

Note that this function does not have access to Rails controller attributes such as `flash` or `params`. Attempts to access what's beyond the arguments passed to the function will result in an error.