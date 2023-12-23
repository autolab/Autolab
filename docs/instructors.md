# Guide for Instructors

This document provides instructors with a brief overview of the basic ideas and capabilities of the Autolab system. It's meant to be read from beginning to end the first time.

## Users

_Users_ are either _instructors_, _course assistants_, or _students_. Instructors have full permissions. Course assistants are only allowed to enter grades. Students see only their own work. Each user is uniquely identified by their email address. You can change the permissions for a particular user at any time. Note that some instructors opt to give some or all of their TAs instructor status.

## Roster

The _roster_ holds the list of users. You can add and remove users one at a time, or in bulk by uploading a CSV file in the general Autolab format:

```
Semester,email,last_name,first_name,school,major,year,grading_policy,courseNumber,courseLecture,section
```

or in the format that is exported by the CMU S3 service:

```
"Semester","Course","Section","Lecture","Mini","Last Name","First Name","MI","AndrewID","Email","College","Department",...
```

!!! warning "Attention CMU Instructors:"
    S3 lists each student twice: once in a lecture roster, which lists the lecture number (e.g., 1, 2,...) in the section field, and once in a section roster, which lists the section letter (e.g., A, B,...) in the section field. Be careful not to import the lecture roster. Instead, export and upload each section individually. Or you can export everything from S3 with a single action, edit out the roster entries for the lecture(s), and then upload a single file to Autolab with all of the sections.

For the bulk upload, you can choose to either:

1. **add** any new students in the roster file to the Autolab roster, or to

2. **update** the Autolab roster by marking students missing from roster files as _dropped_.

For a linked course, you can sync the Autolab roster by clicking the refresh button above the table of users on the 'Manage Course Users' page.

The behavior of the linked course syncing can be customized by clicking the 'Linked Course Settings' button on the 'Manage Course Users' page.

 * The 'Auto drop students' option when enabled will mark students not enrolled in the linked course as dropped on the Autolab roster.


Instructors and course assistants are never marked as dropped. User accounts are never deleted. Students marked as dropped can still see their work, but cannot submit new work and do not appear on the instructor gradebook. Instructors can change the dropped status of a student at any time.

Once a student is added to the roster for a course, then that course becomes visible to the student when they visit the Autolab site. A student can be enrolled in an arbitrary number of Autolab courses.

## Labs (Assessments)

A _lab_ (or _assessment_) is broadly defined as a submission set; it is anything that your students make submissions (handins) for. This could be a programming assignment, a typed homework, or even an in-class exam. You can create labs from scratch, or reuse them from previous semesters. See the companion [Guide For Lab Authors](/lab/) for info on writing and installing labs.

## Assessment Categories

You can tag each assessment with an arbitrary user-defined _category_, e.g., "Lab", "Exam", "Homework".

## Autograders and Scoreboards

Labs can be _autograded_ or not, at your discretion. When a student submits to an autograded lab, Autolab runs an instructor-supplied _autograder_ program that assigns scores to one or more problems associated with the lab. Autograded labs can have an optional _scoreboard_ that shows (anonymized) results in real-time. See the companion [Guide For Lab Authors](/lab/) for details on writing autograded labs with scoreboards.

## Important Dates

A lab has a _start date_, _due date_, _end date_ and _grading deadline_. The link to a lab becomes visible to students after the start date (it's always visible to instructors). Students can submit until the due date without penalty or consuming grace days. Submission is turned off after the end date. Grades are included in the gradebook's category and course averages only after the grading deadline.

## Handins/Submissions

Once an assessment is live (past the start date), students can begin submitting handins, where each handin is a single file, which can be either a text file or an archive file (e.g., `mm.c`, `handin.tar`). Alternatively, instructors can enable GitHub submission for an assessment in its settings and students can directly link their GitHub account and submit from their repo's corresponding branch. Check [here](/installation/github_integration) for how to set up and try our [demo site](https://nightly.autolabproject.com/) for a feel of its usage.

## Groups

Instructors can enable groups by setting the group size to be greater than 1. By default, students are allowed to form groups on their own. In that case, students can create their own group, ask to join an unsaturated group, or leave their existing group. When a student is in a group, any one member's submission counts towards the group's submission. Alternatively, when instructors disallow students to self-assign, it's best practice for instructors to assign groups through the [Autolab Frontend API](/api-overview).

## Penalties and Extensions

You can set penalties for late handins, set hard limits on the number of handins, or set soft limits that penalize excessive handins on a sliding scale. You can also give a student an _extension_ that
extends the due dates and end dates for that student.

## Grace Days

Autolab provides support for a late handin policy based on _grace days_. Each student has a semester-long budget of grace days that are automatically applied if they handin after the due date. Each late day consumes one of the budgeted grace days. The Autolab system keeps track of the number of grace days that have been used by each student to date. If students run out of grace days and handin late, then there is a fixed late penalty (possibly zero) that can be set by the instructor.

## Problems

Each lab contains at least one _problem_, defined by the instructor, with some point value. Each problem has a name (e.g., "Prob1", "Style") that is unique for the lab (although different labs can have the same problem names).

## Grades

_Grades_ come in a number of different forms:

1. _Problem scores:_ These are scalar values (possibly negative) assigned per problem per submission, either manually by a human grader after the end date, or automatically by an autograder after each submission. Problem scores can also be uploaded (imported) in bulk from a CSV file.

2. _Assessment raw score:_ By default, the raw score is the sum of the individual problem scores, before any penalties are applied. You can override the default raw score calculation. See below.

3. _Assessment total score:_ The total score is the raw score, plus any late penalties, plus any instructor _tweaks_.

4. _Category averages:_ This is the average for a particular student over all assessments in a specific instructor-defined category such as "Labs, or "Exams". By default the category average is the arithmetic mean of all assessment total scores, but it can be overridden. See below.

5. _Course Average:_ By default, the course average is average of all category averages, but can be overridden. See below.

Submissions can be classified as one of three types: "Normal", "No Grade" or "Excused". A "No Grade" submission will show up in the gradebook as NG and a zero will be used when calculating averages. An "Excused" submission will show up in the gradebook as EXC and will not be used when calculating averages.

## Overriding Raw Score Calculations

Autolab computes raw scores for a lab with a Ruby function called `raw_score`. The default is the sum of the individual problem scores. But you can change this by providing your own `raw_score` function in `<labname>.rb` file. For example, to override the raw_score calculation for a lab called `malloclab`, you might add the following `raw_score` function to `malloclab/malloclab.rb`:

```ruby
# In malloclab/malloclab.rb file
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

Note: To make this change live, you must select the "Reload config file" option on the `malloclab` page.

## Overriding Category and Course Averages

The average for a category `foo` is calculated by a default Ruby function called `fooAverage`, which you can override in the `course.rb` file. For example, in our course, we prefer to report the "average" as the total number of normalized points (out of 100) that the student has accrued so far. This helps them understand where they stand in the class, e.g., "Going into the final exam (worth 30 normalized points), I have 60 normalized points, so the only way to get an A is to get 100% on the final." Here's the Ruby function for category "Lab":

```ruby
# In course.rb file
def LabAverage(user)
    pts = (user['datalab'].to_f() / 63.0) * 6.0 +
	  (user['bomblab'].to_f() / 70.0) * 5.0 +
	  (user['attacklab'].to_f() / 100.0) * 4.0 +
	  (user['cachelab'].to_f() / 60.0) * 7.0 +
	  (user['tshlab'].to_f() / 110.0) * 8.0 +
	  (user['malloclab'].to_f() / 120.0) * 12.0 +
	  (user['proxylab'].to_f() / 100.0) * 8.0
    return pts.to_f().round(2)
end
```

In this case, labs are worth a total of 50/100 normalized points. The assessment called `datalab` is graded out of a total of 63 points and is worth 6/50 normalized points.

Here is the Ruby function for category "Exam":

```ruby
# In course.rb file
def ExamAverage(user)
    pts = ((user['midterm'].to_f()/60.0) * 20.0) +
          ((user['final'].to_f()/80.0)* 30.0)
    return pts.to_f().round(2)
end
```

In this case, exams are worth 50/100 normalized points. The assessment called `midterm` is graded out of total of 60 points and is worth 20/50 normalized points.

The course average is computed by a default Ruby function called `courseAverage`, which can be overridden by the `course.rb` file in the course directory. Here is the function for our running example:

```ruby
# In course.rb file
def courseAverage(user)
    pts = user['catLab'].to_f() + user['catExam'].to_f()
    return pts.to_f().round(2)
end
```

In this course, the course average is the sum of the category averages for "Lab" and "Exam".

Note: To make these changes live, you must select "Reload course config file" on the "Manage course" page.

## Customizing Submision File MIME Type Check

By default, Autolab does not perform MIME type check for submission files. However, it allows instructors to define their own MIME type check method in the assessment config file. The corresponding function is `checkMimeType` in `<labname>.rb` file. For example, to prevent students from submitting a binary file to the assessment `malloclab`, you might add the following `checkMimeType` function to `malloclab/malloclab.rb`:

```ruby
# In malloclab/malloclab.rb file
def checkMimeType(contentType, fileName)
    return contentType != "application/octet-stream"
end
```

As of now, the only way to provide a more informative message to student is to raise an error:

```ruby
# In malloclab/malloclab.rb file
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

Note: To make this change live, you must select the "Reload config file" option on the `malloclab` page.

## Handin History

For each lab, students can view all of their submissions, including any source code, and the problem scores, penalties, and total scores associated with those submissions, via the _handin history_ page.

## Gradesheet

The _gradesheet_ (not to be confused with the _gradebook_) is the workhorse grading tool. Each assessment has a separate gradesheet with the following features:

-   Provides an interface for manually entering problem scores (and problem feedback) for the most recent submission from each student.

-   Provides an interface for viewing and annotating the submitted code.

-   Displays the problem scores for the most recent submission for each student, summarizes any late penalties, and computes the total score.

-   Provides a link to each student's handin history.

## Gradebook

The _gradebook_ comes in two forms. The _student gradebook_ displays the grades for a particular student, including total scores for each assessment, category averages, and the course average. The _instructor gradebook_ is a table that displays the grades for the most recent submission of each student, including assessment total scores, category averages and course average.

For the gradebook calculations, submissions are classified as one of three types: "Normal", "No Grade" or "Excused". A "No Grade" submission will show up in the gradebook as NG and a zero will be used when calculating averages. An "Excused" submission will show up in the gradebook as EXC and will not be used when calculating averages.

## Releasing Grades

Manually assigned grades are by default not released, and therefore not visible to students. You can release grades on an individual basis while grading, or release all available grades in bulk by using the "Release all grades" option. You can also reverse this process using the "Withdraw all grades" option. (The word "withdraw" is perhaps unfortunate. No grades are ever deleted. They are simply withdrawn from the student's view.)