This page details all the endpoints of the Autolab REST API.

The client's access token should be included as a parameter to all endpoints. For details on obtaining access tokens, please see the [API Overview](/api-overview/).

## Routing

For version 1 of the API, all endpoints are under the path `/api/v1/`. For example, to get user info, send a request to `https://<host>/api/v1/user`.

## Request & Response Format

All endpoints expect the HTTP GET method unless otherwise specified.

All parameters listed below are required unless denoted [OPTIONAL].

All responses are in JSON format.

-   If the request is completed successfully, the HTTP response code will be 200. The reference below details the keys and their respective value types that the client can expect from each endpoint.
-   If an error occurs, the response code will _not_ be 200. The returned JSON will be an object with the key 'error'. Its value will be a string that explains the error.

**Notes on return value types**

All datetime formats are strings in the form of `YYYY-MM-DDThh:mm:ss.sTZD`, e.g. `2017-10-23T04:17:41.000-04:00`, which means 4:17:41 AM on October 23rd, 2017 US Eastern Time.

JSON spec only has a 'number' type, but the spec below distinguishes between integers and floats for ease of use in certain languages.

If a field does not exist, the value is generally null. Please be sure to check if a value is null before using it.

## Interface

---

### user

Get basic user info.

**Scope:** 'user_info'

**Endpoint:** `/user`

**Parameters:** [none]

**Responses:**

| key        | type   | description                     |
| ---------- | ------ | ------------------------------- |
| first_name | string | The user's first name.          |
| last_name  | string | The user's last name.           |
| email      | string | The user's registered email.    |
| school     | string | The school the user belongs to. |
| major      | string | The user's major of study.      |
| year       | string | The user's year.                |

---

### courses

Get all courses currently taking or taken before.

**Scope:** 'user_courses'

**Endpoint:** `/courses`

**Parameters:**

-   state

    [OPTIONAL] filter the courses by the state of the course. Should be one of 'disabled', 'completed', 'current', or 'upcoming'. If no state is provided, all courses are returned.

**Responses:**

A list of courses. Each course contains:

| key          | type    | description                                                                                                           |
| ------------ | ------- | --------------------------------------------------------------------------------------------------------------------- |
| name         | string  | The unique url-safe name.                                                                                             |
| display_name | string  | The full name of the course.                                                                                          |
| semester     | string  | The semester this course is being offered.                                                                            |
| late_slack   | integer | The number of seconds after a deadline that the server will still accept a submission and not count it as late.       |
| grace_days   | integer | AKA late days. The total number of days (over the entire semester) a student is allowed to submit an assessment late. |
| auth_level   | string  | The user's level of access for this course. One of 'student', 'course_assistant', or 'instructor'.                    |

---

### assessments

Get all the assessments of a course.

**Scope:** 'user_courses'

**Endpoint:** `/courses/{course_name}/assessments`

**Parameters:** [none]

**Responses:**

A list of assessments. If the user is only a student of the course, only released assessments are available. Otherwise, all assessments are available. Each assessment contains:

| key              | type     | description                                                                                               |
| ---------------- | -------- | --------------------------------------------------------------------------------------------------------- |
| name             | string   | The unique url-safe name.                                                                                 |
| display_name     | string   | The full name of the assessments.                                                                         |
| start_at         | datetime | The time this assessment is released to students.                                                         |
| due_at           | datetime | Students can submit before this time without being penalized or using grace days.                         |
| end_at           | datetime | Last possible time that students can submit (except those granted extensions.)                            |
| category_name    | string   | Name of the category this assessment belongs to.                                                          |

---

### assessment details

#### show

Show detailed information of an assessment.

**Scope:** 'user_courses'

**Endpoint:** `GET /courses/{course_name}/assessments/{assessment_name}`

**Parameters:** [none]

**Response:**

| key              | type     | description                                                                                               |
| ---------------- | -------- | --------------------------------------------------------------------------------------------------------- |
| name             | string   | The unique url-safe name.                                                                                 |
| display_name     | string   | The full name of the assessments.                                                                         |
| description      | string   | A short description of the assessment.                                                                    |
| start_at         | datetime | The time this assessment is released to students.                                                         |
| due_at           | datetime | Students can submit before this time without being penalized or using grace days.                         |
| end_at           | datetime | Last possible time that students can submit (except those granted extensions.)                            |
| updated_at       | datetime | The last time an update was made to the assessment.                                                       |
| max_grace_days   | integer  | Maximum number of grace days that a student can spend on this assessment.                                 |
| max_submissions  | integer  | The maximum number of times a student can submit the assessment.<br>-1 means unlimited submissions.       |
| max_unpenalized_submissions  | integer  | The maximum number of times the assessment can be submitted without incurring a penalty.<br>-1 means unlimited submissions.|
| disable_handins  | boolean  | Are handins disallowed by students?                                                                       |
| category_name    | string   | Name of the category this assessment belongs to.                                                          |
| group_size       | integer  | The maximum size of groups for this assessment.                                                           |
| writeup_format   | string   | The format of this assessment's writeup.<br>One of 'none', 'url', or 'file'.                              |
| handout_format   | string   | The format of this assessment's handout.<br>One of 'none', 'url', or 'file'.                              |
| has_scoreboard   | boolean  | Does this assessment have a scoreboard?                                                                   |
| has_autograder   | boolean  | Does this assessment use an autograder?                                                                   |

---

#### set group settings

set the group size of the assessment.

**Scope:** 'user_courses'

**Endpoint:** `POST /courses/{course_name}/assessments/{assessment_name}/set_group_settings`

**Parameters:** 

| key              | type     | description                                                                                               |
| ---------------- | -------- | --------------------------------------------------------------------------------------------------------- |
| group_size       | integer  | the number of people in a group                                                                           |
| allow_student_assign_group       | boolean  | whether students are allowed to edit and self-assign groups                               |

**Response:**

| key              | type     | description                                                                                               |
| ---------------- | -------- | --------------------------------------------------------------------------------------------------------- |
| group_size       | integer  | the number of people in a group                                                                           |
| allow_student_assign_group       | boolean  | whether students are allowed to edit and self-assign groups                               |

---

### groups

#### index

List all groups in an assessment

**Scope:** 'instructor_all'

**Endpoint:** `GET /courses/{course name}/assessments/{assessment name}/groups`

**Parameters:**


`show_members`

| key          |          | type    | description                                          |
| ------------ |----------|---------|------------------------------------------------------|
| show_members | optional | boolean | whether to retrieve the members of each group or not |

---

**Response:**

A JSON object containing the group_size, a list of groups, and the assessment containing the groups.
If `show_members` is set to true, a list of `assessment_user_datum` objects will be retrieved for each group as well.


#### show

Show the details of a group and its members

**Scope:** 'instructor_all'

**Endpoint:** `GET /courses/{course name}/assessments/{assessment name}/groups/{id}`

**Parameters:** [none]

**Response:**

The requested group object.


#### create

Create groups in the assessment, given the emails of the people in the group, and an optional group name.

**Scope:** 'instructor_all'

**Endpoint:** `POST /courses/{course name}/assessments/{assessment name}/groups`

**Parameters:** 


`Groups`

| key          |          | type    | description                                                                                               |
| ------------ | -------- | ------- | --------------------------------------------------------------------------------------------------------- |
| groups       | required | string  | List of `group`s to be created. Refer to group object.                                                      |

---

`Group`

| key          |          | type    | description                                                                                               |
| ------------ | -------- | ------- | --------------------------------------------------------------------------------------------------------- |
| name         |          | string  | Name of the group                                                                                         |
| group_members| required | list of string | List of emails of students in that group |

---


Example json object
```
{
    "groups" : [{
        "name": "hello",
        "group_members": ["user@foo.bar","user1@foo.bar"]
    },
    {
        "name": "hello2",
        "group_members": ["user2@foo.bar",""user3@foo.bar"]
    } ]
}
```

**Response:**

A list of the groups created if successful. Otherwise an error message will be returned.

#### destroy

Delete a certain group of an assessment given the id

**Scope:** 'instructor_all'

**Endpoint:** `DELETE /courses/{course name}/assessments/{assessment name}/groups/{id}`

**Parameters:** [none]

**Response:**

Success message if deleted. 

---

### problems

#### index

Get all problems of an assessment.

**Scope:** 'instructor_all'

Endpoint `GET /courses/{course_name}/assessments/{assessment_name}/problems`

**Parameters:** [none]

**Responses:**

A list of problems. Each problem contains:

| key         | type    | description                              |
| ----------- | ------- | ---------------------------------------- |
| name        | string  | Full name of the problem.                |
| description | string  | Brief description of the problem.        |
| max_score   | float   | Maximum possible score for this problem. |
| optional    | boolean | Is this problem optional?                |

---

#### create

Create a problem for an assessment.

**Scope:** 'instructor_all'

Endpoint `POST /courses/{course_name}/assessments/{assessment_name}/problems`

**Parameters:**

| key         | type    | description                              |
| ----------- | ------- | ---------------------------------------- |
| name        | string  | Full name of the problem.                |
| description | string  | Brief description of the problem.        |
| max_score   | float   | Maximum possible score for this problem. |
| optional    | boolean | Is this problem optional?                |

**Responses:**

The newly created problem.

| key         | type    | description                              |
| ----------- | ------- | ---------------------------------------- |
| name        | string  | Full name of the problem.                |
| description | string  | Brief description of the problem.        |
| max_score   | float   | Maximum possible score for this problem. |
| optional    | boolean | Is this problem optional?                |

---

### scores

#### index

Get the submission scores for all users for an assessment.

**Scope:** 'instructor_all'

Endpoint `GET /courses/{course_name}/assessments/{assessment_name}/scores`

**Parameters:** [none]

**Responses:**

A dictionary containing the submission data for each student that's made a submission.
The keys are students' emails, and the values are a dictionary with keys equal to the submission number, and values equal to the scores for the graded problems.

Example json object
```
{
    "student1@andrew.cmu.edu" : {
        "1": {
            "problem1": 100.0,
            "problem2": 10.0
        },
        "2": {
            "problem1": 100.0,
            "problem2": 15.0
        }
    },
    "student2@andrew.cmu.edu" : {
        "1": {}
    }
}
```

---

#### show

Get the submission scores for a user for an assessment.

**Scope:** 'instructor_all'

Endpoint `GET /courses/{course_name}/assessments/{assessment_name}/scores/{email}`

**Parameters:** [none]

**Response:**

A dictionary containing the submission data for the student.
The keys are the submission number, and values equal to the scores for the graded problems.

Example json response:
```
{
    "1": {
        "Problem 1": 100.0,
        "Problem 2": 10.0
    }
}
```

---

#### update_latest

Update the scores for a student's latest submission.

**Scope:** 'instructor_all'

Endpoint `PUT /courses/{course_name}/assessments/{assessment_name}/scores/{email}/update_latest/`

**Parameters:**

| key                 | type        | description                                                                                            |
|---------------------|-------------|--------------------------------------------------------------------------------------------------------|
| update_group_scores | boolean     | Should the score update be propagated to the students in the student's group?                          |
| problems            | json object | Keys equal to the name of the problems to update, values equal to the updated score for a problem |

**Responses:**

-   If any of the problems in `problems` does not exist for the assessment

| key   | type   | value                                        |
|-------| ------ |----------------------------------------------|
| error | string | "Problem '...' not found in this assessment" |

In this case, no score updates will be saved.

-   If all of the problems in `problems` exist for the assessment

The a dictionary with keys equal to the email of the users with updated scores, values equal to the scores for the latest submission.

Example json response:
```
{
    "student1@andrew.cmu.edu": {
        "Problem 2": 10.0,
        "Problem 1": 10.0
    },
    "student2@andrew.cmu.edu": {
        "Problem 2": 10.0,
        "Problem 1": 10.0
    }
}
```

---

### writeup

Get the writeup of an assessment.

**Scope:** 'user_courses'

**Endpoint:** `/courses/{course_name}/assessments/{assessment_name}/writeup`

**Parameters:** [none]

**Responses:**

-   If no writeup exists:

| key     | type   | value  |
| ------- | ------ | ------ |
| writeup | string | "none" |

-   If writeup is a url:

| key | type   | description             |
| --- | ------ | ----------------------- |
| url | string | The url of the writeup. |

-   If writeup is a file:<br>
    The file is returned.

---

### handout

Get the handout of an assessment.

**Scope:** 'user_courses'

**Endpoint:** `/courses/{course_name}/assessments/{assessment_name}/handout`

**Parameters:** [none]

**Responses:** [same as [writeup](/api-interface/#writeup)]

---

### submit

Make a submission to an assessment.

**Scope:** 'user_submit'

**Endpoint:** `POST /courses/{course_name}/assessments/{assessment_name}/submit`

**Parameters:**

-   submission[file]

    The file to submit

    _Note: the name should be the string 'submission[file]'_

**Success Response:**

| key      | type    | description                                              |
| -------- | ------- | -------------------------------------------------------- |
| version  | integer | The version number of the newly submitted submission.    |
| filename | string  | The final filename the submitted file is referred to as. |

**Failure Response:**

A valid submission request may still fail for many reasons, such as file too large, handins disabled by staff, deadline has passed, etc.

When a submission fails, the HTTP response code will not be 200. The response body will include a json with the key 'error'. Its contents will be a user-friendly string that the client may display to the user to explain why the submission has failed. The client _must not_ repeat the request without any modifications. The client is _not_ expected to be able to handle the error automatically.

---

### submissions

Get all submissions the user has made.

**Scope:** 'user_scores'

**Endpoint:** `/courses/{course_name}/assessments/{assessment_name}/submissions`

**Parameters:** [none]

**Response:**

A list of submissions. Each submission includes:

| key        | type     | description                                                                                                                                                                                                               |
| ---------- | -------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| version    | integer  | The version number of this submission.                                                                                                                                                                                    |
| filename   | string   | The final filename the submitted file is referred to as.                                                                                                                                                                  |
| created_at | datetime | The time this submission was made.                                                                                                                                                                                        |
| scores     | object   | A dictionary containing the scores of each problem.<br>The keys are the names of the problems, and the value is either the score (a float), or the string 'unreleased' if the score for this problem is not yet released. |

---

### feedback

Get the text feedback given to a problem of a submission.

For autograded assessments, the feedback will by default be the autograder feedback, and will be identical for all problems.

**Scope:** 'user_scores'

**Endpoint:** `/courses/{course_name}/assessments/{assessment_name}/submissions/{submission_version}/feedback`

**Parameters:**

-   problem

    The name of the problem that the feedback is given to.

**Response:**

| key      | type   | description                              |
| -------- | ------ | ---------------------------------------- |
| feedback | string | The full feedback text for this problem. |

---

### course_user_data (enrollments)

Autolab uses the term course_user_data to represent the users affiliated with a course. It includes all students, course assistants, and instructors of the course.

A course_user_data object in the response will be formatted in this form:

| key          | type    | description                                                                                        |
| ------------ | ------- | -------------------------------------------------------------------------------------------------- |
| first_name   | string  | The user's first name.                                                                             |
| last_name    | string  | The user's last name.                                                                              |
| email        | string  | The user's registered email.                                                                       |
| school       | string  | The school the user belongs to.                                                                    |
| major        | string  | The user's major of study.                                                                         |
| year         | string  | The user's year.                                                                                   |
| lecture      | string  | The user's assigned lecture.                                                                       |
| section      | string  | The user's assigned section.                                                                       |
| grade_policy | string  | The user's grade policy for this course.                                                           |
| nickname     | string  | The user's nickname for this course.                                                               |
| dropped      | boolean | Is the user marked as dropped from this course?                                                    |
| auth_level   | string  | The user's level of access for this course. One of 'student', 'course_assistant', or 'instructor'. |

There are five endpoints related to course_user_data:

#### index

List all course_user_data of a course.

**Scope:** 'instructor_all'

**Endpoint:** `GET /courses/{course_name}/course_user_data`

**Parameters:** [none]

**Response:**

A list of course_user_data objects.

#### show

Show the course_user_data of a particular student in a course.

**Scope:** 'instructor_all'

**Endpoint:** `GET /courses/{course_name}/course_user_data/{user_email}`

**Parameters:** [none]

**Response:**

The requested user's course_user_data object.

#### create

Create a new course_user_data for a course.

The user's email is used to uniquely identify the user on Autolab. If the user is not yet a user of Autolab, they need to be registered on Autolab before they can be enrolled in any courses.

**Scope:** 'instructor_all'

**Endpoint:** `POST /courses/{course_name}/course_user_data`

**Parameters:**

| key          |          | type    | description                                                                                               |
| ------------ | -------- | ------- | --------------------------------------------------------------------------------------------------------- |
| email        | required | string  | The email of the user (to uniquely identify the user).                                                    |
| lecture      | required | string  | The lecture to assign the user to.                                                                        |
| section      | required | string  | The section to assign the user to.                                                                        |
| grade_policy |          | string  | The user's grade policy (opaque to Autolab).                                                              |
| dropped      |          | boolean | Should the user be marked as dropped?                                                                     |
| nickname     |          | string  | The nickname to give the user.                                                                            |
| auth_level   | required | string  | The level of access this user has for this course. One of 'student', 'course_assistant', or 'instructor'. |

**Response:**

The newly created course_user_data object.

#### update

Update an existing course_user_data.

**Scope:** 'instructor_all'

**Endpoint:** `PUT /courses/{course_name}/course_user_data/{user_email}`

**Parameters:**

| key          |     | type    | description                                                                                               |
| ------------ | --- | ------- | --------------------------------------------------------------------------------------------------------- |
| lecture      |     | string  | The lecture to assign the user to.                                                                        |
| section      |     | string  | The section to assign the user to.                                                                        |
| grade_policy |     | string  | The user's grade policy (opaque to Autolab).                                                              |
| dropped      |     | boolean | Should the user be marked as dropped?                                                                     |
| nickname     |     | string  | The nickname to give the user.                                                                            |
| auth_level   |     | string  | The level of access this user has for this course. One of 'student', 'course_assistant', or 'instructor'. |

**Response:**

The newly updated course_user_data object.

#### destroy

Drop a user from a course. Since CUDs are never deleted from the course, this is just a shortcut for updating a user with the dropped attribute set to true.

**Scope:** 'instructor_all'

**Endpoint:** `DELETE /courses/{course_name}/course_user_data/{user_email}`

**Parameters:** [none]

**Response:**

The newly updated course_user_data object.
