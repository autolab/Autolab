# Guide for Lab Authors

This guide explains how to create autograded programming assignments (labs) for the Autolab system. While **reading through the documentation is recommended**, for a quick start, here's a <a href="https://youtu.be/GQ2EkBcRH4k" target="_blank">short video</a> that gives a brief introduction of autograders.

## Writing Autograders

An _autograder_ is a program that takes a student's work as input, and generates some quantitative evaluation of that work as output. The student's work consists of one or more source files written in an arbitrary programming language. The autograder processes these files and generates arbitrary text lines on stdout. What's written to stdout will be displayed to the students as **autograder feedback**.

!!! info "Streaming Output"
	As of Autolab v2.10, any output written into the stdout will be streamed directly for students to see, so students can see the live progress of the autograding. Many programming languages do buffered writes to `stdout`, so if you want live progress, you would have to guarantee that you are writing to stdout by flushing the buffer accordingly (e.g. [Python `print`'s flush flag](https://docs.python.org/3/library/functions.html#print), [C's `fflush`](https://www.tutorialspoint.com/c_standard_library/c_function_fflush.htm), [CPP's `fflush` ](https://en.cppreference.com/w/cpp/io/c/fflush)) 

The last text line on stdout must be a JSON string, called an _autoresult_, that assigns an autograded score to one or more problems, and optionally, generates the scoreboard entries for this submission.

The JSON autoresult is a "scores" hash that assigns a numerical score to one or more problems, and an optional "scoreboard" array that provides the scoreboard entries for this submission. For example,

```json
{ "scores": { "Prob1": 10, "Prob2": 5 } }
```

assigns 10 points to "Prob1" and 5 points to "Prob2" for this submission. The names of the problems must exactly match the names of the problems for this lab on the Autolab web site. Not all problems need to be autograded. For example, there might be a problem for this assessment called "Style" that you grade manually after the due date.

If you used the Autolab web site to configure a scoreboard for this lab with three columns called "Prob1", "Prob2", and "Total", then the autoresult might be:

```json
{ "scores": { "Prob1": 10, "Prob2": 5 }, "scoreboard": [10, 5, 15] }
```

By convention, an autograder accepts an optional `-A` command line argument that tells it to emit the JSON autoresult. So if you run the autograder outside of the context of Autolab, you can suppress the autoresult line by calling the autograder without the `-A` argument.

One of the nice properties of Autolab autograders is that they can be written and tested offline, without requiring any interaction with Autolab. Writing autograders is not easy, but the fact that they can be developed offline allows you to develop and test them in your own familiar computing environment.

To format your autoresult feedback provided to the students, use the [formatted feedback feature](/features/formatted-feedback).

## Installing Autograded Labs

After you've written and tested the autograder, you then use the Autolab web site to create the autograded lab. Autolab supports creating new labs from scratch, or reusing labs from previous semesters. We'll describe each of these in turn.

### Creating an Autograded Lab from Scratch

#### Step 1: Create the new lab.

Create a new lab by clicking the "Install Assessment" button and choosing "Option 1: Create a New Assessment from Scratch." For course `<course>` and lab `<lab>`, this will create a <i>lab directory</i> in the Autolab file hierarchy called `courses/<course>/<lab>`. This initial directory contains a couple of config files and a directory called `<lab>/handin` that will contain all of the student handin files. In general, you should never modify any of these.

!!! warning "Attention CMU Lab Authors"
	At CMU, the lab directory is called `/afs/cs/academic/class/<course>/autolab/<lab>`. For example: `/afs/cs/academic/class/15213-f16/autolab/foo` is the lab directory for the lab named `foo` for the Fall 2016 instance of 15-213. All lab-related files must go in this `autolab` directory to avoid permissions issues.

#### Step 2: Configure the lab for autograding.

Using the "Edit Assessment" page, turn on autograding for this lab by selecting "Add Autograder." You will be asked for the name of the image to be used for autograding this lab. The default image distributed with Autolab is an Ubuntu image called `autograding_image`. If your class needs different software, then you or your facilities staff will need to update the default image or create a new one.

!!! warning "Attention CMU Lab Authors"
	The default autograding image at CMU is called `rhel.img` and is a copy of the software on the CMU Andrew machines (`linux.andrew.cmu.edu`). If you need custom software installed, please send mail to autolab-help@andrew.cmu.edu.

If you want a scoreboard, you should select "Add Scoreboard," which will allow you to specify the number of columns and their names. The "Add Scoreboard" page contains a tutorial on how to do this.

You'll also need to define the names and point values for all the problems in this lab, including the autograded ones.

Each student submission is a single file, either a text source file or an archive file containing multiple files and directories. You'll need to specify the _base name_ for the student submission files (e.g., `mm.c`, `handin.tar`).

#### Step 3: Add the required autograding files.

For an autograded lab, Autolab expects the following two _autograding files_ in the lab directory:

-   `autograde-Makefile`: runs the autograder on a student submission.
-   `autograde.tar`: contains all of the files (except for the student handin file) that are needed for autograding.

Each time a student submits their work or an instructor requests a regrade, Autolab

1. copies the student handin file, along with the two autograding files, to an empty directory on an _autograding instance_,
2. renames the student handin file to _base name_ (e.g., hello.c, handin.tar),
3. renames `autograde-Makefile` to `Makefile`,
4. executes the command `make` on the autograding instance, and finally
5. captures the stdout generated by the autograder, and parses the resulting JSON autoresult to determine the autograded scores.

### Importing an Autograded Lab from a Previous Semester

If you've created a lab for a course in a previous semester and have access to the lab directory (as we do at CMU via AFS), you can import the lab into your current course by

1. copying the lab directory from the previous course to the current course,
2. cleaning out the `handin` directory, then
3. visiting the "Install Assessment" page and selecting "Option 2: Import an existing assessment from the file system." Autolab will give you a list of all of the directories that appear to be uninstalled labs, from which you can select your particular lab.

If you don't have access to the lab directory, another option is to import a lab from a tarball that was created by running "Export assessment" in an instance of a lab from a previous semester. Visit the "Install Assessment" page and select "Option 3: Import an existing assessment from tarball." This will upload the tarball, create a new lab directory by expanding the tarball, and then import the directory.

## Example: Hello Lab

In this section we'll look at the simplest possible autograded lab we could imagine, called, appropriately enough, the <a href="https://github.com/autolab/Autolab/tree/master/examples/hello" target="_blank">Hello Lab</a> (with <a href="https://github.com/autolab/Autolab/tree/master/examples/hello.tar" target="_blank">tarball</a>), which is stored in a lab directory called `hello` in the Autolab github repo. While it's trivial, it illustrates all of the aspects of developing an autograded lab, and provides a simple example that you can use for sanity testing on your Autolab installation.

In this lab, students are asked to write a version of the K&R "hello, world" program, called `hello.c`. The autograder simply checks that the submitted `hello.c` program compiles and runs with an exit status of zero. If so, the submission gets 100 points. Otherwise it gets 0 points.

### Directory Structure

Autolab expects to find the `autograde-Makefile`and `autograde.tar` files in the `hello` lab directory, but otherwise places no constraints on the contents and organization of this directory. However, based on our experience, we strongly recommend a directory structure with the following form:

<a href="https://github.com/autolab/Autolab/tree/master/examples/hello/README" target="_blank">hello/README</a>:

```md
# Basic files created by the lab author

Makefile              Builds the lab from src/
README
autograde-Makefile    Makefile that runs the autograder
src/                  Contains all src files and solutions  
test-autograder/      For testing autograder offline
writeup/              Lab writeup that students view from Autolab

# Files created by running make

hello-handout/        The directory that is handed out to students, created
                      using files from src/.
hello-handout.tar     Archive of hello-handout directory
autograde.tar         File that is copied to the autograding instance
                      (along with autograde-Makefile and student handin file)

# Files created and managed by Autolab

handin/               All students handin files
hello.rb              Config file
hello.yml             Database properties that persist from semester to semester
log.txt               Log of autograded submissions
```

The key idea with this directory structure is to place _all_ code for the lab in the `src` directory, including the autograding code and any starter code handed out to students in the handout directory (`hello-handout.tar` in this example). Keeping all hard state in the `src` directory helps limit inconsistencies.

The main makefile creates `hello-handout` by copying files from `src`, and then tars it up:

<a href="https://github.com/autolab/Autolab/tree/master/examples/hello/Makefile" target="_blank">hello/Makefile</a>:

```makefile
#
# Makefile to manage the example Hello Lab
#

# Get the name of the lab directory
LAB = $(notdir $(PWD))

all: handout handout-tarfile

handout:
	# Rebuild the handout directory that students download
	(rm -rf $(LAB)-handout; mkdir $(LAB)-handout)
	cp -p src/Makefile-handout $(LAB)-handout/Makefile
	cp -p src/README-handout $(LAB)-handout/README
	cp -p src/hello.c-handout $(LAB)-handout/hello.c
	cp -p src/driver.sh $(LAB)-handout

handout-tarfile: handout
	# Build *-handout.tar and autograde.tar
	tar cvf $(LAB)-handout.tar $(LAB)-handout
	cp -p $(LAB)-handout.tar autograde.tar

clean:
	# Clean the entire lab directory tree.  Note that you can run
	# "make clean; make" at any time while the lab is live with no
	# adverse effects.
	rm -f *~ *.tar
	(cd src; make clean)
	(cd test-autograder; make clean)
	rm -rf $(LAB)-handout
	rm -f autograde.tar
#
# CAREFULL!!! This will delete all student records in the logfile and
# in the handin directory. Don't run this once the lab has started.
# Use it to clean the directory when you are starting a new version
# of the lab from scratch, or when you are debugging the lab prior
# to releasing it to the students.
#
cleanallfiles:
	# Reset the lab from scratch.
	make clean
	rm -f log.txt
	rm -rf handin/*
```

Filenames are disambiguated by appending `-handout`, which is stripped when they are copied to the handout directory. For example, `src/hello.c` is the instructor's solution file, and `src/hello.c-handout` is the starter code that is given to the students in `hello-handout/hello.c`. And `src/README` is the README for the src directory and `src/README-handout` is the README that is handed out to students in `hello-handout/README`.

To build the lab, type `make clean; make`. You can do this as often as you like while the lab is live with no adverse effects. However, be careful to never type `make cleanallfiles` while the lab is live; this should only be done before the lab goes live; never during or after.

### Source Directory

The <a href="https://github.com/autolab/Autolab/tree/master/examples/hello/src" target="_blank">hello/src/</a> directory
contains _all_ of the code files for the Hello Lab, including the files that are handed out to students:

<a href="https://github.com/autolab/Autolab/tree/master/examples/hello/src/README" target="_blank">hello/src/README</a>:

```
# Autograder and solution files
Makefile                Makefile and ...
README                  ... README for this directory
driver.sh*              Autograder
hello.c                 Solution hello.c file

# Files that are handed out to students
Makefile-handout        Makefile and ...
README-handout          ... README handed out to students
hello.c-handout         Blank hello.c file handed out to students
```

### Handout Directory

The <a href="https://github.com/autolab/Autolab/tree/master/examples/hello/hello-handout/" target="_blank">hello/hello-handout/</a> directory
contains the files that the students will use to work on the lab. It contains no hard state, and is populated entirely with files from `hello/src`:

<a href="https://github.com/autolab/Autolab/tree/master/examples/hello/hello-handout/README" target="_blank">hello/hello-handout/README</a>:

```
For this lab, you should write a tiny C program, called "hello.c",
that prints "hello, world" to stdout and then indicates success by
exiting with a status of zero.

To test your work:
$ make clean; make; ./hello

To run the same autograder that Autolab will use when you submit:
$ ./driver.sh

Files:
README          This file
Makefile        Compiles hello.c
driver.sh       Autolab autograder
hello.c         Empty C file that you will edit
```

<a href="https://github.com/autolab/Autolab/tree/master/examples/hello/hello-handout/Makefile" target="_blank">hello/hello-handout/Makefile</a> contains the rules that compile the student source code:

```makefile
# Student makefile for the Hello Lab
all:
	gcc hello.c -o hello

clean:
	rm -rf *~ hello
```

To compile and run their code, students type:

```bash
$ make clean; make
$ ./hello
```

### Autograder

The autograder for the Hello Lab is a trivially simple bash script called `driver.sh` that compiles and runs `hello.c` and verifies that it returns with an exit status of zero:

<a href="https://github.com/autolab/Autolab/tree/master/examples/hello/src/driver.sh" target="_blank">hello/src/driver.sh</a>:

```bash
#!/bin/bash

# driver.sh - The simplest autograder we could think of. It checks
#   that students can write a C program that compiles, and then
#   executes with an exit status of zero.
#   Usage: ./driver.sh

# Compile the code
echo "Compiling hello.c"
(make clean; make)
status=$?
if [ ${status} -ne 0 ]; then
    echo "Failure: Unable to compile hello.c (return status = ${status})"
    echo "{\"scores\": {\"Correctness\": 0}}"
    exit
fi

# Run the code
echo "Running ./hello"
./hello
status=$?
if [ ${status} -eq 0 ]; then
    echo "Success: ./hello runs with an exit status of 0"
    echo "{\"scores\": {\"Correctness\": 100}}"
else
    echo "Failure: ./hello fails or returns nonzero exit status of ${status}"
    echo "{\"scores\": {\"Correctness\": 0}}"
fi

exit
```

For example:

```bash
$ ./driver.sh
# Compiling hello.c
# rm -rf *~ hello
# gcc hello.c -o hello
# Running ./hello
# Hello, world
# Success: ./hello runs with an exit status of 0
# {"scores": {"Correctness": 100}}
```

Notice that the autograder expects the `hello` lab on the Autolab front-end to have been defined with a problem called "Correctness", with a maximum value of 100 points. If you forget to define the problems listed in the JSON autoresult, scores will still be logged, but they won't be posted to the database.

### Required Autograding Files

Autolab requires two _autograding files_ called `autograde.tar`, which contains all of the code required by the autograder, and `autograde-Makefile`, which runs the autograder on the autograding image when each submission is graded.

For the Hello Lab, `autograde.tar` is simply a copy of the `hello-handout.tar` file that is handed out to students. And here is the corresponding
<a href="https://github.com/autolab/Autolab/tree/master/examples/hello/autograde-Makefile" target="_blank">hello/autograde-makefile</a>:

```makefile
all:
	tar xvf autograde.tar
	cp hello.c hello-handout
	(cd hello-handout; ./driver.sh)

clean:
	rm -rf *~ hello-handout
```

The makefile expands `autograde.tar` into `hello-handout`, copies `hello.c` (the submission file) into `hello-handout`, changes directory to `hello-handout`, builds the autograder, and then runs it.

### Test Directory

For our labs, we like to setup a test directory (called `test-autograder` in this example), that allows us to test our `autograde-Makefile` and `autograde-tar` files by simulating Autolab's behavior on the autograding instance. The `test-autograder` directory has the following form:

```bash
$ cd test-autograder
$ ls -l
# total 3
# lrwxr-xr-x 1 droh users  21 Aug  4 16:43 Makefile -> autograde-Makefile
# lrwxr-xr-x 1 droh users  16 Aug  4 16:43 autograde.tar -> autograde.tar
# -rw-rw-r-- 1 droh users 113 Aug  4 16:44 hello.c
```

To simulate Autolab's behavior on an autograding instance:

```bash
$ cd test-autograder && make clean && make
# Running ./hello
# Hello, world
# Success: ./hello runs with an exit status of 0
# {"scores": {"Correctness": 100}}
```

### Writeup directory

The `hello/writeup` contains the detailed lab writeup, either html or pdf file, that students can download from the Autolab front end.

## Other sample autograders
We have a [repository for sample autograders](https://github.com/autolab/autograders-examples) written for popular languages, which includes Python, Java, C++, Golang, and Javascript.

## Overriding Modify Submission Score

By default, the score output by the autograder will directly assigned to the individual problem scores. But you can change this by providing your own `modifySubmissionScores` function in `<labname>.rb` file. For example, to override the score calculation for a lab called `malloclab`, you might add the following `modifySubmissionScores` function to `malloclab/malloclab.rb`:

```ruby
# In malloclab/malloclab.rb file
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
This overriding allows you to create a lab that has a score that is a function of the number of previous submissions, and the scores of previous submissions. This particular lab has four problems called "Autograded Score", "Score1", "Score2", "Score3". It assigns the score of "Score1" to be the negative of the number of previous submissions, and the score of "Score2" to be the score of "Score1" of the previous submission, and the score of "Score3" to be the score of "Score2" of the previous submission. 

There are two settings that you can change in the `assessmentVariables` function that will affect the behavior of the `modifySubmissionScores` function:

- `previous_submissions_lookback`: The number of previous submissions to look back when calculating the score. By default, it is set to 1000.
- `exclude_autograding_in_progress_submissions`: If set to `true`, the submissions that are currently being autograded will be excluded when passed into the `modifySubmissionScores` function. By default, it is set to `false`.

The three arguments passed into the `modifySubmissionScores` function are:

- `scores`: A hash that maps the problem name to the score.
- `previous_submissions`: A list of previous submissions, sorted by submission time in descending order, it is an ActiveRecord object.
- `problems`: A list of problems in the lab, it is an ActiveRecord object.

For more information on how to use ActiveRecord, please refer to the [ActiveRecord documentation](http://guides.rubyonrails.org/active_record_querying.html). For the schema of the `Submission` and `Problem` models, please refer to the [Autolab Schema](https://github.com/autolab/Autolab/blob/master/db/schema.rb).

To make this change live, you must select the "Reload config file" option on the assessment page.

## Troubleshooting

#### Why is Autolab not displaying my stdout output?

Autolab always shows the stdout output of running make, even when the program crashed or timed out. However, when it does crash and the expected autoresult json string is not appended to the output, parsing of the last line will fail. If this happens, any stdout output that is longer than 10,000 lines will be discarded (Note that this limit does not apply when the autoresult json is valid).

#### Why is Autolab not able to stream my stdout output? The output only seems to be displayed when autograding is completed.

Autolab can only stream stdout. Many programming languages do buffered writes to `stdout`, so you would have to guarantee that you are writing to stdout by flushing the buffer accordingly (e.g. [Python `print`'s flush flag](https://docs.python.org/3/library/functions.html#print), [C's `fflush`](https://www.tutorialspoint.com/c_standard_library/c_function_fflush.htm), [CPP's `fflush` ](https://en.cppreference.com/w/cpp/io/c/fflush))