# Autolab Features Documentation

This guide details the usage of features in Autolab.

Features Documented (Work in Progress):

-   [Formatted Feedback](#formatted-feedback)
-   [Scoreboards](#scoreboards)
-   [Embedded Forms](#embedded-forms)
-   [Annotations](#annotations)
-   [MOSS Plagiarism Detection](#moss)

## Formatted Feedback

Autograding feedback plays an important role in a student's Autolab experience. Good feedback provided by autograders can really enhance a student's learning. As of Summer 2020, Autolab includes the formatted feedback feature by [Jala Alamin](https://github.com/alamijal). The feature was originally introduced in Washington State University Vancouver's version of Autolab.

Using formatted feedback requires a prior understanding of how Autolab's autograders work, as per the [Guide for Lab Authors](/lab/#writing-autograders). The formatted feedback feature is an **optional extension** of the default feedback. It comes in a staged fashion, allowing differing levels of adoption.

The next few sections are meant to be read in order, with each following section introducing a more complex usage of the formatted feedback feature than the previous. Experimenting the [hellocat](https://github.com/autolab/Autolab/tree/master/examples/hellocat) example code is another way to familiarize with the formatted feedback.

### Default Feedback

By only outputting the **autoresult** (**autoresult** is the JSON string that needs to be outputted on the last line of stdout, as mentioned in the [Guide for Lab Authors](/lab/#writing-autograders)), the default feedback format will automatically be used.
```json
{ "scores": { "Correctness": 20, "TA/Design/Readability": 40 } }
```

Autolab will simply display the raw output as produced by the autograder

![Default Feedback](/images/feedback/default.png)


### Semantic Feedback (Minimal)

By adding an additional JSON string before the **autoresult**, as follows

```json
{"_presentation": "semantic"}
{ "scores": { "Correctness": 20, "TA/Design/Readability": 40 } }
```
we can invoke the semantic layout, which will display the both the raw output and a formatted table of scores.

![Semantic Minimal](/images/feedback/semantic_minimal.gif)

### Semantic Feedback with Test Cases

By further describing the additional JSON string, we can introduce test stages to the formatted feedback, which we can use to indicate to the student the test cases that have passed and/or failed.

**Actual JSON to be outputted**
```json
{"_presentation": "semantic", "stages": ["Test Results"], "Test Results": {"Build": {"passed": true}, "Run": {"passed": true}}}
{"scores": {"Correctness": 20, "TA/Design/Readability": 40}}
```
**Prettified JSON (for reference only)**
```json
{
  "_presentation": "semantic",
  "stages": ["Test Results"],
  "Test Results": {
    "Build": {
      "passed": true
    },
    "Run": {
      "passed": true
    }
  }
}
{"scores": {"Correctness": 20, "TA/Design/Readability": 40}}
```
We would add `["Test Results"]` to the stages key. Then we would add to the  corresponding `Test Results` key an object containing all the test case results. In this case `Build` and `Run` were used, but you can use other names for the test cases as well.

![Semantic with Test Cases](/images/feedback/semantic_with_test_case.gif)

### Semantic Feedback (Multi-Stage)

Using the same manner in which we add a `Test Stage` in the previous section, we can adapt it to create as many stages as we want. The following example has three different stages, namely `Build`, `Test` and `Timing`, but you can use other names for the stages as well.

**Actual JSON to be outputted**
```json
{"_presentation": "semantic", "stages": ["Build", "Test", "Timing"], "Test": {"Add Things": {"passed": true}, "Return Values": {"passed": false, "hint": "You need to return 1"}}, "Build": {"compile" : {"passed": true}, "link": {"passed": true}}, "Timing": {"Stage 1 (ms)": 10, "Stage 2 (ms)": 20}}
{"scores": {"Correctness": 20, "TA/Design/Readability": 40}}
```

**Prettified JSON (for reference only)**
```json
{
  "_presentation": "semantic",
  "stages": ["Build","Test","Timing"],
  "Test": {
    "Add Things": {
      "passed": true
    },
    "Return Values": {
      "passed": false,
      "hint": "You need to return 1"
    }
  },
  "Build": {
    "compile": {
      "passed": true
    },
    "link": {
      "passed": true
    }
  },
  "Timing": {
    "Stage 1 (ms)": 10,
    "Stage 2 (ms)": 20
  }
}
{"scores": {"Correctness": 20, "TA/Design/Readability": 40}}
```

We would add the stages we want into the `stages` array. Then we would add those corresponding stages as a separate key, with each of them holding their own set of test case results. We are also able to provide hints if the student gets the particular test case wrong by adding a `hint` key to the test case.

![Semantic Multistage with Hint](/images/feedback/semantic_multistage_with_hint.gif)

## Scoreboards

Scoreboards are created by the output of [Autograders](/lab/#writing-autograders). They anonomously rank students submitted assignments inspiring health competition and desire to improve. They are simple and highly customizable. Scoreboard's can be added/edited on the edit assessment screen (`/courses/<course>/assessments/<assessment>/edit`).

![Scoreboard Edit](/images/scoreboard_edit.png)

In general, scoreboards are configured using a JSON string.

### Default Scoreboard

The default scoreboard displays the total problem scores, followed by each individual problem score, sorted in descending order by the total score.

### Custom Scoreboards

Autograded assignments have the option of creating custom scoreboards. You can specify your own custom scoreboard using a JSON column specification.

The column spec consists of a "scoreboard" object, which is an array of JSON objects, where each object describes a column.

**Example:** a scoreboard with one column, called `Score`.

```json
{
    "scoreboard": [{ "hdr": "Score" }]
}
```

A custom scoreboard sorts the first three columns, from left to right, in descending order. You can change the default sort order for a particular column by adding an optional "asc:1" element to its hash.

**Example:** Scoreboard with two columns, "Score" and "Ops", with "Score" sorted descending, and then "Ops" ascending:

```json
{
    "scoreboard": [{ "hdr": "Score" }, { "hdr": "Ops", "asc": 1 }]
}
```

### Scoreboard Entries

The values for each row in a custom scoreboard come directly from a `scoreboard` array object in the autoresult string produced by the Tango, the autograder.

**Example:** Autoresult returning the score (97) for a single autograded problem called `autograded`, and a scoreboard entry with two columns: the autograded score (`Score`) and the number of operations (`Ops`):

```json
{
    "scores": {
        "autograded": 97
    },
    "scoreboard": [97, 128]
}
```

For more information on how to use Autograders and Scoreboards together, visit the [Guide for Lab Authors](/lab/).

## Embedded Forms

This feature allows an instructor to create an assessment which does not require a file submission on the part of the student. Instead, when an assessment is created, the hand-in page for that assessment will display an HTML form of the instructor’s design. When the student submits the form, the information is sent directly in JSON format to the Tango grading server for evaluation.

!!! attention "Tango Required"
	Tango is needed to use this feature. Please install [Tango](/tango/) and connect it to Autolab before proceeding.

![Embedded Form](/images/embedded_form_example.png)

### Creating an Embedded Form

Create an HTML file with a combination of the following elements. The HTML file need only include form elements, because it will automatically be wrapped in a `<form></form>` block when it is rendered on the page.

In order for the JSON string (the information passed to the grader) to be constructed properly, your form elements must follow the following conventions:

-   A unique name attribute
-   A value attribute which corresponds to the correct answer to the question (unless it is a text field or text area)

HTML Form Reference:

**Text Field (For short responses)**

```html
<input type="“text”" name="“question-1”" />
```

**Text Area (For coding questions)**

```html
<textarea name="“question-2”" style="“width:100%”" />
```

**Radio Button (For multiple choice)**

```html
<div class="row">
    <label>
       <input name="question-3" type="radio" value="object" id="q3-1" />
       <span>Object</span>
    </label>

    <label>
       <input name="question-2" type="radio" value="boolean" id="q3-2" />
       <span>Boolean</span>
    </label>
</div>
```

**Dropdown (For multiple choice or select all that apply)**

```html
<select multiple name="question-4">
    <option value="1">Option 1</option>
    <option value="2">Option 2</option>
    <option value="3">Option 3</option>
</select>
```

**Example Form (shown in screenshot above)**

```html
<div>
    <h6>What's your name?</h6>
    <input type="text" name="question-1" id="q1"/>
</div>

<div>
    <h6>Which year are you?</h6>
    <div class="row">
        <label>
        <input name="question-2" type="radio" value="freshman" id="q3-1" />
        <span>Freshman</span>
        </label>
        <label>
        <input name="question-2" type="radio" value="sophomore" id="q3-2" />
        <span>Sophomore</span>
        </label>
        <label>
        <input name="question-2" type="radio" value="junior" id="q3-3" />
        <span>Junior</span>
        </label>
        <label>
        <input name="question-2" type="radio" value="senior" id="q3-4" />
        <span>Senior</span>
        </label>
    </div>
</div>

<div>
    <h6>What's your favorite language?</h6>

    <select name="question-3" id="q4">
        <option value="C">C</option>
        <option value="Python">Python</option>
        <option value="Java">Java</option>
    </select>
</div>
```

Navigate to the Basic section of editing an assessment (`/courses/<course>/assessments/<assessment>/edit`), check the check box, and upload the HTML file. Ensure you submit the form by clicking `Save` at the bottom of the page.

![Embedded Form Edit](/images/embedded_quiz_edit.png)

### Grading an Embedded Form

When a student submits a form, the form data is sent to [Tango](/tango/) in the form of a JSON string in the file `out.txt.` In your grading script, parse the contents of `out.txt` as a JSON object. The JSON object will be a key-value pair data structure, so you can access the students response string (`value`) by its unique key (the `name` attribute).

For the example form shown above, the JSON object will be as follows:

```json
{
    "utf8": "✓",
    "authenticity_token": "LONGAUTHTOKEN",
    "submission[embedded_quiz_form_answer]": "",
    "question-1": "John Smith",
    "question-2": "junior",
    "question-3": "Python",
    "integrity_checkbox": "1"
}
```

Use this information to do any processing you need in Tango.If you find any problems, please file an issue on the [Autolab Github](https://github.com/autolab/Autolab).


## Annotations

Annotations is a feature introduced as part of the Speedgrader update to Autolab. It allows instructors and TAs to quickly leave comments and grade code at the same time. 

![Annotation Form](/images/annotations.png)

Hover over any line of the code and click on the green arrow, and the annotation form will appear. Add the comment, adjust the score, and select the targetted problem.

!!! attention "Non-Autograded Problems Only"
    Note that annotations can only be added to non-autograded problems. Specifically, a problem is non-autograded if there is no assigned score for that problem in the json outputted by the autograder

### Scoring Behavior

There are two intended ways for course instructors to use the add annotation features. Deductions from maximum, or additions from zero.

**Deductions from maximum**

Set a `max_score` either programmatically, or under `Edit Assessment > Problems` for the particular non-autograded question. Then when the grader is viewing the code, add negative score, such as `-5` into the score field, to deduct from the maximum. This use case is preferred when grading based on a rubric, and the score is deducted for each mistake.

The maximum score can be `0` if the deductions are meant to be penalties, such as for poor code style or violation of library interfaces.

**Additions from zero**

Set a `max_score` either programmatically, or under `Edit Assessment > Problems` for the particular non-autograded question to `0`. When the grader is viewing the code, add positive scores, such as `5` to the score field, to add to the score. This use case is preferred when giving out bonus points.

### Interaction with Gradesheet

We have kept the ability the edit the scores in the gradesheet, as we understand that there are instances in which editing the gradesheet directly is much more efficient and/or needed. However, this leads to an unintended interaction with the annotations.

In particular, modifications on the gradesheet itself will override all changes made to a problem by annotations, but the annotations made will still remain. 

A example would be, if the `max_score` of a problem is `10`. A grader adds an annotation with `-5` score to that problem (so the score is now `10-5=5`). Then if the same/another grader changes the score to `8` on the gradesheet, the final score would be `8`.

**Recommendation**

It is much preferred to grade using annotations whenever possible,
as it provides a better experience for the students who will be able to identify the exact line at which the mistake is made. Gradesheet should be used in situations where the modification is non-code related.


## MOSS Plagiarism Detection Installation

[MOSS (Measure Of Software Similarity)](https://theory.stanford.edu/~aiken/moss/) is a system for checking for plagiarism. MOSS can be setup on Autolab as follows:

1. Obtain the script for MOSS based on the instructions given in [https://theory.stanford.edu/~aiken/moss/](https://theory.stanford.edu/~aiken/moss/).

2. Create a directory called `vendor` at the root of your Autolab installation, i.e

	```bash
	cd <autolab_root>
	mkdir -p vendor
	```

3. Copy the moss script into the `vendor` directory and name it `mossnet`

	```bash
	mv <path_to_moss_script> vendor/mossnet
	```
