# Embedded Forms

This feature allows an instructor to create an assessment which does not require a file submission on the part of the student. Instead, when an assessment is created, the hand-in page for that assessment will display an HTML form of the instructor’s design. When the student submits the form, the information is sent directly in JSON format to the Tango grading server for evaluation.

!!! attention "Tango Required"
	Tango is needed to use this feature. Please install [Tango](/installation/tango/) and connect it to Autolab before proceeding.

![Embedded Form](/images/embedded_form_example.png)

## Creating an Embedded Form

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

## Grading an Embedded Form

When a student submits a form, the form data is sent to [Tango](/installation/tango/) in the form of a JSON string in the file `out.txt.` In your grading script, parse the contents of `out.txt` as a JSON object. The JSON object will be a key-value pair data structure, so you can access the students response string (`value`) by its unique key (the `name` attribute).

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

Use this information to do any processing you need in Tango.If you find any problems, please file an issue on the <a href="https://github.com/autolab/Autolab" target="_blank">Autolab Github</a>.
